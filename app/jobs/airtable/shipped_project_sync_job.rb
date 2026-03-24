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
      "Optional - Override Hours Spent" => submission.approved_hours&.to_f,
      "Optional - Override Hours Spent Justification" => submission.optional_override_hours_spent_justification
    }
    if (name = ship_status_airtable_field_name.presence)
      fields[name] = submission.ship_status
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
    if project.reviewed? && project.status.to_s == "approved"
      return approved_override_hours_justification(project)
    end

    parts = [ "EDIT ME" ]
    parts << "Hour Justification: #{project.hour_justification}" if project.hour_justification.present?
    parts << "Reviewed by: #{project.reviewed_by.name}"         if project.reviewed_by.present?
    parts << "Reviewed at: #{project.reviewed_at&.strftime('%Y-%m-%d %H:%M UTC')}" if project.reviewed_at.present?
    parts.join("\n")
  end

  # Default copy for Airtable "Optional - Override Hours Spent Justification" when the submission is approved.
  def approved_override_hours_justification(project)
    mention = reviewer_mention_for_justification(project)
    approved = project.approved_hours.to_f
    raw = project.total_hours.to_f
    reduced = raw > approved
    body =
      if reduced
        "Project reviewed by #{mention}. Approved reduced #{format_hours_justification(raw)} to #{format_hours_justification(approved)} hours, as the timing didn't seem fair, and both the demo and repository looked solid, including the heartbeats."
      else
        "Project reviewed by #{mention}. Approved #{format_hours_justification(approved)} hours, as the timing seems reasonable, and both the demo and repository looked solid, including the heartbeats."
      end
    comment = project.admin_feedback.to_s.strip
    if comment.present?
      body += "\n\nReviewer-User comment: #{comment}."
    end
    body
  end

  # Prefer name snapshotted on approve (avoids nil reviewed_by / deleted admin users); else load User by id.
  def reviewer_mention_for_justification(project)
    label = project.read_attribute(:approver_display_name).presence
    if label.blank?
      uid = project.read_attribute(:reviewed_by_user_id)
      reviewer = User.find_by(id: uid) if uid.present?
      reviewer ||= project.reviewed_by
      label = reviewer&.jackpot_profile_name
    end
    label = label.to_s.delete_prefix("@").strip
    label = "unknown" if label.blank?
    "@#{label}"
  end

  def format_hours_justification(n)
    f = n.to_f
    return "0.0" unless f.finite?

    format("%.1f", f)
  end
end
