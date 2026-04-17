class Airtable::ShippedProjectSyncJob < Airtable::BaseSyncJob
  def perform
    YswsProjectSubmission.ensure_rows_for_shipped_projects!
    super
  end

  def table_name
    ENV.fetch("AIRTABLE_SHIPPED_PROJECTS_TABLE", "YSWS Project Submission")
  end

  def records
    YswsProjectSubmission
      .joins(:project)
      .merge(Project.shipped)
      .includes(project: [ :user, :reviewed_by ])
  end

  def field_mapping(submission)
    # Ship status: only sent when AIRTABLE_YSWS_SHIP_STATUS_FIELD is set to the *exact* Airtable column name.
    # Add that field in Airtable first (e.g. Single select: Pending, Approved, Rejected — or Single line text).
    #
    # Every field below still syncs Jackpot → Airtable on each run, except:
    # "Optional - Override Hours Spent Justification" — not listed here, so Airtable keeps whatever is there
    # (including manual edits). That column is pulled into PG after sync via
    # YswsProjectSubmission#pull_optional_override_hours_justification_from_airtable!
    fields = {
      "Code URL" => submission.code_url,
      "Playable URL" => submission.playable_url,
      "Description" => submission.description,
      "Screenshot" => submission.banner_url.present? ? [ { "url" => submission.banner_url } ] : nil,
      "First Name" => submission.first_name,
      "Last Name" => submission.last_name,
      "Email" => submission.email,
      slack_id_airtable_field => submission.slack_id,
      "GitHub Username" => submission.github_username,
      "Address (Line 1)" => submission.address_line_1,
      "Address (Line 2)" => submission.address_line_2,
      "City" => submission.city,
      "State / Province" => submission.state,
      "Country" => submission.country,
      "ZIP / Postal Code" => submission.postal_code,
      "Birthday" => submission.birthday,
      "Optional - Override Hours Spent" => submission.approved_hours&.to_f
    }
    if (name = ship_status_airtable_field_name.presence)
      fields[name] = submission.ship_status
    end
    ud_field = YswsProjectSubmission.update_desc_airtable_field_name
    if submission.update_desc_log.to_s.strip.present?
      fields[ud_field] = submission.update_desc_log
    end
    fields.compact
  end

  private

  def slack_id_airtable_field
    ENV.fetch("AIRTABLE_YSWS_SLACK_FIELD", "Slack ID")
  end

  def ship_status_airtable_field_name
    ENV["AIRTABLE_YSWS_SHIP_STATUS_FIELD"]
  end

  def push_record!(submission)
    return unless submission.is_a?(YswsProjectSubmission)
    return unless submission.project&.shipped?

    super
  end

  def sync_single_record(record, index = nil, raise_on_error: false)
    project = record.project
    identity = fetch_identity(project.user)
    record.apply_mirror_fields!(identity)
    super(record, index, raise_on_error: raise_on_error)
    record.pull_automation_first_submitted_at_from_airtable!
    record.pull_double_dip_from_airtable!
    record.pull_optional_override_hours_justification_from_airtable!
  end

  def fetch_identity(user)
    @identity_cache ||= {}
    @identity_cache[user.id] ||= begin
      HCAService.identity(user.access_token)
    rescue => e
      Rails.logger.warn("ShippedProjectSyncJob: failed to fetch identity for user #{user.id}: #{e.message}")
      {}
    end
  end
end
