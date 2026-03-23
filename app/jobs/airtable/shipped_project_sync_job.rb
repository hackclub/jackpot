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
    {
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
      "Optional - Override Hours Spent" => submission.approved_hours&.to_f,
      "Optional - Override Hours Spent Justification" => submission.optional_override_hours_spent_justification
    }.compact
  end

  private

  def slack_id_airtable_field
    ENV.fetch("AIRTABLE_YSWS_SLACK_FIELD", "Slack ID")
  end

  def sync_single_record(record, index = nil)
    project = record.project
    identity = fetch_identity(project.user)
    record.apply_mirror_fields!(identity, justification_text(project))
    super
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

  def justification_text(project)
    parts = [ "EDIT ME" ]
    parts << "Hour Justification: #{project.hour_justification}" if project.hour_justification.present?
    parts << "Reviewed by: #{project.reviewed_by.name}"         if project.reviewed_by.present?
    parts << "Reviewed at: #{project.reviewed_at&.strftime('%Y-%m-%d %H:%M UTC')}" if project.reviewed_at.present?
    parts.join("\n")
  end
end
