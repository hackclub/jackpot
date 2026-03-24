class Airtable::JournalEntrySyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_JOURNAL_ENTRIES_TABLE", "_journal_entries")
  end

  def records
    JournalEntry.all
  end

  def field_mapping(entry)
    {
      "Project Name" => entry.project_name,
      "id" => entry.id.to_s,
      "Description" => entry.description,
      "Hours Worked" => entry.hours_worked.to_f,
      "Tools Used" => (entry.tools_used || []).join(", "),
      "Time Done" => entry.time_done&.iso8601,
      "Created At" => entry.created_at&.iso8601
    }
  end

  def perform
    super
    update_projects_total_hours
  end

  private

  def update_projects_total_hours
    project_ids = JournalEntry.where.not(project_id: nil).distinct.pluck(:project_id)
    Project.where(id: project_ids).find_each(&:update_total_hours)
  end
end
