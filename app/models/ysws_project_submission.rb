class YswsProjectSubmission < ApplicationRecord
  belongs_to :project

  def self.ensure_rows_for_shipped_projects!
    shipped_ids = Project.shipped.pluck(:id)
    return if shipped_ids.empty?

    existing = where(project_id: shipped_ids).pluck(:project_id)
    missing = shipped_ids - existing
    return if missing.empty?

    now = Time.current
    insert_all(
      missing.map { |id| { project_id: id, created_at: now, updated_at: now } }
    )
  end

  def apply_mirror_fields!(identity, justification_text)
    p = project
    assign_attributes(
      code_url: p.code_url,
      playable_url: p.playable_url,
      description: p.description,
      banner_url: p.banner_url,
      first_name: identity["first_name"],
      last_name: identity["last_name"],
      email: p.user.email,
      slack_id: p.user.slack_id,
      github_username: identity["github"],
      address_line_1: identity.dig("address", "line_1") || identity["address_line_1"],
      address_line_2: identity.dig("address", "line_2") || identity["address_line_2"],
      city: identity.dig("address", "city") || identity["city"],
      state: identity.dig("address", "state") || identity["state"],
      country: identity.dig("address", "country") || identity["country"],
      postal_code: identity.dig("address", "postal_code") || identity["postal_code"],
      birthday: identity["birthday"],
      approved_hours: p.approved_hours,
      optional_override_hours_spent_justification: justification_text
    )
    save!
  end
end
