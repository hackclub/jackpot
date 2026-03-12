# Syncs projects to Airtable from the local database.
# Pushes project data for external tracking/reporting.
class Airtable::ProjectSyncJob < Airtable::BaseSyncJob
  # @return [String] Airtable table name
  def table_name
    ENV.fetch("AIRTABLE_PROJECTS_TABLE", "_projects")
  end

  # @return [ActiveRecord::Relation] all Project records
  def records
    Project.all
  end

  # Maps Project attributes to Airtable fields.
  # @param project [Project] the project to map
  # @return [Hash] Airtable field values
  def field_mapping(project)
    {
      "Name" => project.name,
      "Description" => project.description,
      "Type" => project.project_type,
      "Code URL" => project.code_url,
      "Playable URL" => project.playable_url,
      "Hackatime Projects" => (project.hackatime_projects || []).join(", "),
      "Hackatime Hours" => project.hackatime_hours.to_f,
      "Shipped" => project.shipped,
      "Shipped At" => project.shipped_at&.iso8601,
      "Status" => project.status,
      "Reviewed" => project.reviewed,
      "Reviewed At" => project.reviewed_at&.iso8601,
      "Approved Hours" => project.approved_hours.to_f,
      "Chips Earned" => project.chips_earned.to_f,
      "Admin Feedback" => project.admin_feedback,
      "Hour Justification" => project.hour_justification,
      "Banner URL" => project.banner_url,
      "Created At" => project.created_at&.iso8601
    }
  end
end
