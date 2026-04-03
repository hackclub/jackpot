# frozen_string_literal: true

class User < ApplicationRecord
  include AirtablePushOnChange

  has_encrypted :access_token
  has_many :journal_entries, foreign_key: :user_id, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :shop_orders, dependent: :destroy
  has_many :shop_item_requests, dependent: :destroy
  has_many :project_comments, dependent: :destroy
  enum :role, { user: 0, reviewer: 1, admin: 2, super_admin: 3 }, prefix: true

  validates :hack_club_id, presence: true, uniqueness: true
  validates :email, presence: true
  validates :access_token, presence: true
  validate :safe_profile_photo_url

  pushes_airtable_with Airtable::UserSyncJob

  scope :active, -> { where("last_sign_in_at > ?", 6.months.ago) }

  def self.from_omniauth(auth)
    user = find_or_initialize_by(hack_club_id: auth.uid)
    user.assign_attributes(
      email: auth.info.email,
      display_name: auth.info.name || auth.info.email.split("@").first,
      access_token: auth.credentials.token,
      provider: auth.provider,
      last_sign_in_at: Time.current,
      profile_photo_url: auth.info.image || auth.extra&.raw_info&.dig("profile", "image_192")
    )

    slack_id = auth.info.slack_id
    user.slack_id = slack_id if slack_id.present?

    if user.profile_photo_url.blank? && slack_id.present?
      user.fetch_slack_photo(slack_id)
    end

    if user.slack_username.blank? && slack_id.present?
      user.fetch_slack_username(slack_id)
    end

    user.role ||= :user
    user.save!
    user
  end

  def fetch_slack_photo(slack_id)
    token = Rails.application.credentials.slack_bot_token
    return unless token && slack_id

    uri = URI("https://slack.com/api/users.profile.get")
    uri.query = URI.encode_www_form({ user: slack_id })

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      if data["ok"]
        image = data.dig("profile", "image_192") || data.dig("profile", "image_512")
        self.profile_photo_url = image if image.present?
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to fetch Slack photo: #{e.message}"
  end

  def update_access_token!(token)
    update!(access_token: token, last_sign_in_at: Time.current)
  end

  def fetch_slack_username(slack_id)
    token = Rails.application.credentials.slack_bot_token
    return unless token && slack_id

    uri = URI("https://slack.com/api/users.profile.get")
    uri.query = URI.encode_www_form({ user: slack_id })

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      Rails.logger.info "Slack API Response received for user"
      if data["ok"] && data["profile"]
        username = data.dig("profile", "display_name").presence ||
                   data.dig("profile", "real_name").presence ||
                   data.dig("profile", "display_name_normalized")
        self.slack_username = username
        Rails.logger.info "Set slack_username to: #{username}"
      else
        Rails.logger.warn "Slack API returned ok=false: #{data['error']}"
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to fetch Slack username: #{e.message}"
  end

  def leaderboard_name
    slack_username.presence || display_name.presence || email.split("@").first
  end

  # Name shown next to the profile photo in Jackpot (admin review / deck UI).
  def jackpot_profile_name
    slack_username.presence || display_name.presence || email.to_s.split("@").first.presence || hack_club_id.presence || "Admin"
  end

  def eligible_hackatime_projects
    hackatime_id = slack_id || hack_club_id
    return [] unless hackatime_id

    service = HackatimeService.new
    start_date = Date.new(2026, 2, 14)

    projects_data = service.get_user_project_stats(hackatime_id, start_date: start_date)
    return [] unless projects_data

    projects_data.select { |p| (p["total_seconds"] || 0) > 0 }
  end

  def name
    display_name.presence || email
  end

  def role_admin?
    super
  end

  # Review queue + stats + deck review endpoints (not shop / console / Blazer).
  def review_privileged?
    role_reviewer? || role_admin? || role_super_admin?
  end

  # Full admin panel: shop, items request, console, engines, etc.
  def full_admin?
    role_admin? || role_super_admin?
  end

  # approved_hours is total approved hours on the project. Pass new_chip_award when only a *delta* of hours
  # was approved this round (re-ship); chip_am increases by that delta only.
  def approve_project(project_index, approved_hours, justification = nil, feedback = nil, new_chip_award: nil)
     return false unless projects && projects[project_index.to_i]

     idx = project_index.to_i
     approved_hours_float = approved_hours.to_f

     delta_chips =
       if new_chip_award.nil?
         JackpotHours.chips_from_approved_hours(approved_hours_float)
       else
         new_chip_award.to_f.round(2)
       end

     projects[idx]["reviewed"] = true
     projects[idx]["status"] = "approved"
     projects[idx]["approved_hours"] = approved_hours_float
     projects[idx]["hour_justification"] = justification
     projects[idx]["admin_feedback"] = feedback
     projects[idx]["reviewed_at"] = Time.current.iso8601
     prev_slot_chips = projects[idx]["chips_earned"].to_f
     projects[idx]["chips_earned"] =
       if new_chip_award.nil?
         delta_chips
       else
         (prev_slot_chips + delta_chips).round(2)
       end

     self.chip_am = (chip_am || 0) + delta_chips

     update!(projects: projects, chip_am: chip_am)
   end

  def reject_project(project_index, feedback = nil)
    return false unless projects && projects[project_index.to_i]

    idx = project_index.to_i
    projects[idx]["reviewed"] = true
    projects[idx]["status"] = "rejected"
    projects[idx]["admin_feedback"] = feedback
    projects[idx]["reviewed_at"] = Time.current.iso8601
    update!(projects: projects)
  end

  # When a Project AR row is deleted, remove the matching slot from legacy jsonb `users.projects` (if any).
  # Shipped and unshipped projects may still have entries here; leaving them causes stale data in admin tooling.
  def remove_legacy_jsonb_slot_for_project!(project)
    raw = read_attribute(:projects)
    return unless raw.is_a?(Array) && raw.any?

    ordered_ids = projects.order(position: :asc).pluck(:id)
    idx = ordered_ids.index(project.id)
    arr = raw.deep_dup
    pid = project.id

    if idx && idx < arr.length
      slot = arr[idx]
      slot_pid = slot.is_a?(Hash) ? (slot["id"] || slot[:id]) : nil
      if slot_pid.blank? || slot_pid.to_i == pid
        arr.delete_at(idx)
      end
    end

    arr.reject! do |slot|
      slot.is_a?(Hash) && (slot["id"] || slot[:id]).to_i == pid
    end

    update_columns(projects: arr, updated_at: Time.current)
  end

  # Keep legacy jsonb `users.projects` in sync when the user removes a shipped-but-not-approved project from the review queue.
  def unship_project_voluntary_from_queue!(project_index)
    raw = read_attribute(:projects)
    return false unless raw.is_a?(Array)

    idx = project_index.to_i
    return false if idx.negative?

    arr = raw.deep_dup
    while arr.length <= idx
      arr << {}
    end

    slot = arr[idx]
    slot = slot.is_a?(Hash) ? slot.stringify_keys.dup : {}
    slot["shipped"] = false
    slot.delete("shipped_at")
    slot["status"] = "pending"
    slot["reviewed"] = false
    slot.delete("reviewed_at")
    slot.delete("approved_hours")
    slot.delete("chips_earned")
    slot.delete("hour_justification")
    slot.delete("admin_feedback")
    arr[idx] = slot
    update_columns(projects: arr, updated_at: Time.current)
  end

  # Keep legacy jsonb `users.projects` column in sync when a shipped project is rejected (not the has_many :projects association).
  def unship_project_after_rejection!(project_index, admin_feedback: nil, restore_approved_hours: nil)
    raw = read_attribute(:projects)
    return false unless raw.is_a?(Array)

    idx = project_index.to_i
    return false if idx.negative?

    arr = raw.deep_dup
    while arr.length <= idx
      arr << {}
    end

    slot = arr[idx]
    slot = slot.is_a?(Hash) ? slot.stringify_keys.dup : {}
    slot["shipped"] = false
    slot.delete("shipped_at")
    slot["status"] = "rejected"
    slot["reviewed"] = false
    slot.delete("reviewed_at")
    if restore_approved_hours.present?
      slot["approved_hours"] = restore_approved_hours.to_f
    else
      slot.delete("approved_hours")
    end
    slot.delete("chips_earned")
    slot.delete("hour_justification")
    slot["admin_feedback"] = admin_feedback if admin_feedback.present?
    arr[idx] = slot
    # Write the jsonb column only — `update!(projects: arr)` hits the has_many setter and raises
    # "Project expected, got Hash" because each slot is a Hash, not a Project record.
    update_columns(projects: arr, updated_at: Time.current)
  end

  # Sum of Hackatime hours on all projects plus all journal entries (pending + shipped).
  def total_logged_hours
    if has_attribute?(:logged_hours_total)
      read_attribute(:logged_hours_total).to_f
    else
      projects.sum { |p| p.hackatime_hours.to_f } + journal_entries.sum(:hours_worked).to_f
    end
  end

  # Sum of approved_hours on approved projects (matches reviewer totals; 1 hr → 50 chips when awarded).
  def total_approved_hours
    if has_attribute?(:approved_hours_total)
      read_attribute(:approved_hours_total).to_f
    else
      projects.where(status: "approved").sum(:approved_hours).to_f
    end
  end

  # Wallet balance (after shop spend, refunds, etc.).
  def current_chips
    chip_am.to_f
  end

  # Sum of chips_earned on approved projects (lifetime awarded; differs from current when user has spent chips).
  def total_chips
    if has_attribute?(:chips_earned_total)
      read_attribute(:chips_earned_total).to_f
    else
      projects.where(status: "approved").sum(Arel.sql("COALESCE(chips_earned, 0)")).to_f
    end
  end

  private

  def safe_profile_photo_url
    return if profile_photo_url.blank?
    unless profile_photo_url.match?(/\Ahttps?:\/\//i)
      errors.add(:profile_photo_url, "must start with http:// or https://")
    end
  end
end
