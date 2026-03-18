class Airtable::ShippedProjectSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_SHIPPED_PROJECTS_TABLE", "_shipped_projects")
  end

  def airtable_id_field
    :shipped_airtable_id
  end

  def synced_at_field
    :shipped_synced_at
  end

  def records
    Project.shipped.includes(:user, :reviewed_by)
  end

  def field_mapping(project)
    identity = fetch_identity(project.user)

    {
      "Code URL"            => project.code_url,
      "Playable URL"        => project.playable_url,
      "Description"         => project.description,
      "Screenshot"          => project.banner_url.present? ? [ { "url" => project.banner_url } ] : nil,
      "First Name"          => identity["first_name"],
      "Last Name"           => identity["last_name"],
      "Email"               => project.user.email,
      "Slack ID"            => project.user.slack_id,
      "GitHub Username"     => identity["github"],
      "Address (Line 1)"    => identity.dig("address", "line_1") || identity["address_line_1"],
      "Address (Line 2)"    => identity.dig("address", "line_2") || identity["address_line_2"],
      "City"                => identity.dig("address", "city")   || identity["city"],
      "State / Province"    => identity.dig("address", "state")  || identity["state"],
      "Country"             => identity.dig("address", "country") || identity["country"],
      "ZIP / Postal Code"   => identity.dig("address", "postal_code") || identity["postal_code"],
      "Birthday"            => identity["birthday"],
      "Optional - Override Hours Spent" => project.approved_hours&.to_f,
      "Optional - Override Hours Spent Justification" => justification_text(project)
    }.compact
  end

  private

  # Fetches HCA identity for a user; caches per-job run to avoid redundant API calls
  # when multiple projects belong to the same user.
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
