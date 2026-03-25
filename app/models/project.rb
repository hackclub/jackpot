class Project < ApplicationRecord
  include GithubRepositoryKey
  include AirtablePushOnChange

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_one :ysws_project_submission, dependent: :destroy
  has_many :project_comments, dependent: :destroy
  has_many :journal_entries, dependent: :destroy

  validates :name, :user_id, presence: true
  validate :safe_urls

  pushes_airtable_with Airtable::ProjectSyncJob

  after_commit :enqueue_shipped_ysws_airtable_push, on: %i[create update]

  scope :shipped, -> { where(shipped: true) }
  scope :reviewed, -> { where(reviewed: true) }
  scope :pending_review, -> { where(status: "in-review", reviewed: false) }

  # Shipped rows that count as “the same repo already in the queue” (not displaced by a rejected resubmit).
  ACTIVE_SHIP_QUEUE_STATUSES = %w[in-review approved].freeze

  before_create :set_position

  def set_position
    self.position = user.projects.count
  end

  def update_total_hours
    journal_hours = JournalEntry.where(user_id: user_id, project_id: id).sum(:hours_worked).to_f || 0
    hackatime_hours = self.hackatime_hours.to_f || 0
    total = journal_hours + hackatime_hours
    self.update_column(:total_hours, total)
  end

  def enqueue_shipped_ysws_airtable_push
    return unless shipped?

    sub = YswsProjectSubmission.ensure_row_for_project!(self)
    return unless sub

    Airtable::PushRecordJob.enqueue_if_configured(Airtable::ShippedProjectSyncJob, sub.id)
  end

  # Re-shipping after admin rejection: remove a leftover YSWS row if the DB was out of sync.
  def clear_stale_ysws_submission_if_any!
    return unless status.to_s == "rejected"

    s = ysws_project_submission
    return unless s

    begin
      s.delete_remote_airtable_record!
    rescue StandardError => e
      Rails.logger.warn("Project##{id} clear_stale_ysws: Airtable delete skipped: #{e.message}")
    end
    s.destroy
    reload
  end

  # When this (rejected) project is shipped again, remove any other shipped submission for the same GitHub repo
  # that is still in-review or approved so the new ship is the only active queue entry.
  def displace_conflicting_shipped_same_repo!
    key = self.class.github_repository_key(code_url)
    return if key.blank?

    user.projects.shipped.where.not(id: id).find_each do |other|
      next unless self.class.github_repository_key(other.code_url) == key
      next unless ACTIVE_SHIP_QUEUE_STATUSES.include?(other.status.to_s)

      other.displaced_by_same_repo_resubmit!
    end
  end

  def displaced_by_same_repo_resubmit!
    note = "This submission was removed from the review queue because the same GitHub repository was resubmitted from another project after corrections."
    chips = chips_earned.to_f
    uid = user_id

    begin
      ysws_project_submission&.delete_remote_airtable_record!
    rescue StandardError => e
      Rails.logger.warn("Project##{id} displaced_by_same_repo_resubmit: Airtable delete: #{e.message}")
    end
    ysws_project_submission&.destroy

    combined_feedback = [ admin_feedback, note ].compact.join("\n\n").strip.presence

    update!(
      shipped: false,
      shipped_at: nil,
      shipped_airtable_id: nil,
      shipped_synced_at: nil,
      status: "rejected",
      reviewed: false,
      reviewed_at: nil,
      reviewed_by_user_id: nil,
      approver_display_name: nil,
      approved_hours: nil,
      chips_earned: nil,
      hour_justification: nil,
      admin_feedback: combined_feedback
    )

    if chips.positive?
      u = User.find(uid)
      u.update_column(:chip_am, [ u.chip_am.to_f - chips, 0.0 ].max)
    end

    idx = user.projects.order(position: :asc).pluck(:id).index(id)
    user.unship_project_after_rejection!(idx, admin_feedback: combined_feedback) if idx.present?
  end

  # Shipped but still waiting on admin (not approved): user may leave the queue voluntarily.
  def withdrawable_from_shipping_queue?
    shipped? && status.to_s == "in-review" && !reviewed?
  end

  # Remove from YSWS / Airtable queue and return to editable deck state (pending, not shipped).
  def withdraw_from_shipping_queue!
    raise ArgumentError, "Project cannot be withdrawn from the queue in its current state" unless withdrawable_from_shipping_queue?

    submission = ysws_project_submission
    attrs = {
      shipped: false,
      shipped_at: nil,
      shipped_airtable_id: nil,
      shipped_synced_at: nil,
      status: "pending",
      reviewed: false,
      reviewed_at: nil,
      reviewed_by_user_id: nil,
      approver_display_name: nil,
      approved_hours: nil,
      chips_earned: nil,
      hour_justification: nil,
      admin_feedback: nil
    }

    if submission
      submission.delete_remote_airtable_record!
      transaction do
        submission.destroy!
        update!(attrs)
      end
    else
      update!(attrs)
    end
  end

  # Admin rejected a shipped submission: delete Airtable row first (avoid orphans), then remove YSWS row and return project to deck.
  def unship_return_to_deck_after_rejection!(admin_feedback: nil)
    submission = ysws_project_submission
    attrs = {
      shipped: false,
      shipped_at: nil,
      shipped_airtable_id: nil,
      shipped_synced_at: nil,
      status: "rejected",
      reviewed: false,
      reviewed_at: nil,
      reviewed_by_user_id: nil,
      approver_display_name: nil,
      admin_feedback: admin_feedback,
      approved_hours: nil,
      chips_earned: nil,
      hour_justification: nil
    }

    if submission
      submission.delete_remote_airtable_record!
      transaction do
        submission.destroy!
        update!(attrs)
      end
    else
      update!(attrs)
    end
  end

  def self.from_json(user, json_projects)
    return [] unless json_projects.present?

    json_projects.each_with_index do |project_data, index|
      next if project_data.nil?

      project = user.projects.find_or_create_by(name: project_data["name"], created_at: project_data["created_at"]) do |p|
        p.description = project_data["description"]
        p.project_type = project_data["project_type"]
        p.code_url = project_data["code_url"]
        p.github_username = project_data["github_username"].to_s.delete_prefix("@") if project_data.key?("github_username")
        p.playable_url = project_data["playable_url"]
        p.hackatime_projects = project_data["hackatime_projects"] || []
        p.shipped = project_data["shipped"] || false
        p.shipped_at = project_data["shipped_at"]
        p.status = project_data["status"] || "pending"
        p.reviewed = project_data["reviewed"] || false
        p.reviewed_at = project_data["reviewed_at"]
        p.approved_hours = project_data["approved_hours"]
        p.hour_justification = project_data["hour_justification"]
        p.admin_feedback = project_data["admin_feedback"]
        p.chips_earned = project_data["chips_earned"]
        p.position = index
      end
      project.save! if project.changed?
    end
  end

  private

  def safe_urls
    %i[code_url playable_url banner_url].each do |attr|
      value = send(attr).to_s.strip
      next if value.blank?
      unless value.match?(/\Ahttps?:\/\//i)
        errors.add(attr, "must start with http:// or https://")
      end
    end
  end
end
