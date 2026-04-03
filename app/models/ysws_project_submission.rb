class YswsProjectSubmission < ApplicationRecord
  include AirtablePushOnChange
  include AirtableSyncedRowDeletion

  SHIP_STATUSES = %w[Pending Approved Rejected].freeze

  belongs_to :project

  pushes_airtable_with Airtable::ShippedProjectSyncJob

  validates :ship_status, inclusion: { in: SHIP_STATUSES }

  def self.ship_status_for_project(project)
    if project.reviewed? && project.status == "approved"
      "Approved"
    elsif project.reviewed? && project.status == "rejected"
      "Rejected"
    else
      "Pending"
    end
  end

  def self.ensure_rows_for_shipped_projects!
    shipped_ids = Project.shipped.pluck(:id)
    return if shipped_ids.empty?

    existing = where(project_id: shipped_ids).pluck(:project_id)
    missing = shipped_ids - existing
    return if missing.empty?

    now = Time.current
    insert_all(
      missing.map { |id| { project_id: id, ship_status: "Pending", created_at: now, updated_at: now } }
    )
  end

  # One shipped project → ensure a submission row exists (for event-driven Airtable push without scanning all projects).
  def self.ensure_row_for_project!(project)
    return nil unless project&.shipped?

    rec = find_or_initialize_by(project_id: project.id)
    rec.ship_status = ship_status_for_project(project)
    rec.save! if rec.new_record? || rec.changed?
    rec
  end

  def self.airtable_sync_table_name
    airtable_shipped_table_name
  end

  def self.airtable_shipped_table_name
    ENV.fetch("AIRTABLE_SHIPPED_PROJECTS_TABLE", "YSWS Project Submission")
  end

  def self.airtable_api_credentials
    token = Rails.application.credentials&.airtable&.acces_token || ENV["AIRTABLE_API_KEY"]
    base_id = Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]
    [ token, base_id ]
  end

  def apply_mirror_fields!(identity, justification_text)
    p = project
    addr = self.class.address_from_identity(identity)
    assign_attributes(
      ship_status: self.class.ship_status_for_project(p),
      code_url: p.code_url,
      playable_url: p.playable_url,
      description: p.description,
      banner_url: p.banner_url,
      first_name: identity["first_name"],
      last_name: identity["last_name"],
      email: p.user.email,
      slack_id: p.user.slack_id,
      github_username: self.class.github_username_for_submission(p, identity),
      address_line_1: addr&.dig("line_1") || identity["address_line_1"],
      address_line_2: addr&.dig("line_2") || identity["address_line_2"],
      city: addr&.dig("city") || identity["city"],
      state: addr&.dig("state") || identity["state"],
      country: addr&.dig("country") || identity["country"],
      postal_code: addr&.dig("postal_code") || identity["postal_code"],
      birthday: identity["birthday"],
      approved_hours: p.approved_hours,
      optional_override_hours_spent_justification: justification_text
    )
    save!
  end


  def self.address_from_identity(identity)
    nested = identity["address"]
    return nested if nested.is_a?(Hash)

    addrs = identity["addresses"]
    return nil unless addrs.is_a?(Array) && addrs.any?

    addrs.find { |a| a.is_a?(Hash) && a["primary"] } || addrs.find { |a| a.is_a?(Hash) }
  end

  def self.github_username_for_submission(project, identity)
    project.github_username.presence ||
      github_from_identity(identity).presence ||
      github_from_code_url(project.code_url)
  end

  def self.github_from_identity(identity)
    gh = identity["github"]
    return gh["login"] if gh.is_a?(Hash) && gh["login"].present?

    %w[github github_username github_login gh_username].each do |key|
      val = identity[key]
      return val if val.is_a?(String) && val.present?
    end

    nil
  end

  def self.automation_first_submitted_airtable_field_name
    ENV.fetch("AIRTABLE_YSWS_AUTOMATION_FIRST_SUBMITTED_AT_FIELD", "Automation - First Submitted At")
  end

  def self.parse_airtable_datetime(raw)
    case raw
    when Time, ActiveSupport::TimeWithZone
      raw
    when Date
      raw.beginning_of_day.in_time_zone
    when String
      Time.zone.parse(raw)
    else
      Time.zone.parse(raw.to_s)
    end
  rescue ArgumentError, TypeError
    nil
  end

  # Filled by Airtable automation after submission to main HC DB; used to block re-ship in Jackpot.
  def pull_automation_first_submitted_at_from_airtable!
    aid = airtable_id
    return if aid.blank?

    token, base_id = self.class.airtable_api_credentials
    return unless token.present? && base_id.present?

    field = self.class.automation_first_submitted_airtable_field_name
    tbl = Norairrecord.table(token, base_id, self.class.airtable_shipped_table_name)
    rec = tbl.find(aid)
    raw = rec[field]
    return if raw.blank?

    parsed = self.class.parse_airtable_datetime(raw)
    return if parsed.blank?

    update_column(:automation_first_submitted_at, parsed) if automation_first_submitted_at != parsed
  rescue StandardError => e
    Rails.logger.warn("YswsProjectSubmission##{id} pull automation timestamp: #{e.message}")
  end

  def self.github_from_code_url(code_url)
    return nil if code_url.blank?

    s = code_url.to_s.strip
    if (m = s.match(%r{\Agit@github\.com:([^/\s?#]+)}i))
      owner = m[1].presence
      return owner if owner.present?
    end

    return nil unless s.match?(/github\.com/i)

    m = s.match(%r{github\.com/([^/\s?#]+)}i)
    return nil unless m

    owner = m[1].to_s
    return nil if owner.blank?

    return nil if %w[orgs settings topics features enterprise].include?(owner.downcase)

    owner
  end
end
