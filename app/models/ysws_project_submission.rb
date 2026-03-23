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
    addr = self.class.address_from_identity(identity)
    assign_attributes(
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
