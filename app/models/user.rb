# frozen_string_literal: true

class User < ApplicationRecord
  has_encrypted :access_token
  has_many :journal_entries, foreign_key: :user_id, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :shop_orders, dependent: :destroy
  has_many :shop_item_requests, dependent: :destroy
  has_many :project_comments, dependent: :destroy
  enum :role, { user: 0, admin: 1 }, prefix: true

  validates :hack_club_id, presence: true, uniqueness: true
  validates :email, presence: true
  validates :access_token, presence: true
  validate :safe_profile_photo_url

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

  def approve_project(project_index, approved_hours, justification = nil, feedback = nil)
     return false unless projects && projects[project_index.to_i]

     idx = project_index.to_i
     approved_hours_float = approved_hours.to_f

     chips_earned = (approved_hours_float * 50).round(2)

     projects[idx]["reviewed"] = true
     projects[idx]["status"] = "approved"
     projects[idx]["approved_hours"] = approved_hours_float
     projects[idx]["hour_justification"] = justification
     projects[idx]["admin_feedback"] = feedback
     projects[idx]["reviewed_at"] = Time.current.iso8601
     projects[idx]["chips_earned"] = chips_earned

     self.chip_am = (chip_am || 0) + chips_earned

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

  # Keep legacy jsonb `users.projects` column in sync when a shipped project is rejected (not the has_many :projects association).
  def unship_project_after_rejection!(project_index, admin_feedback: nil)
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
    slot.delete("approved_hours")
    slot.delete("chips_earned")
    slot.delete("hour_justification")
    slot["admin_feedback"] = admin_feedback if admin_feedback.present?
    arr[idx] = slot
    update!(projects: arr)
  end

  # Sum of Hackatime hours on all projects plus all journal entries (pending + shipped).
  def total_logged_hours
    if has_attribute?(:logged_hours_total)
      read_attribute(:logged_hours_total).to_f
    else
      projects.sum { |p| p.hackatime_hours.to_f } + journal_entries.sum(:hours_worked).to_f
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
