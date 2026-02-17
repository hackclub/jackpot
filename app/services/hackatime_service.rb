class HackatimeService
  BASE_URL = "https://hackatime.hackclub.com/api/v1"

  def initialize
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def get_user_project_stats(slack_id, start_date: nil, end_date: nil)
    response = @conn.get("users/#{slack_id}/stats") do |req|
      req.params["features"] = "projects"
      req.params["start_date"] = start_date.to_s if start_date
      req.params["end_date"] = end_date.to_s if end_date
    end

    unless response.success?
      Rails.logger.error("Hackatime API Request Failed: #{response.status} - #{response.body}")
      return nil
    end

    body = response.body || {}
    if body.dig("trust_factor", "trust_value") == 1
      Rails.logger.warn("User #{slack_id} is flagged as untrusted by Hackatime.")
      return nil
    end

    body.dig("data", "projects") || []
  rescue Faraday::Error => e
    Rails.logger.error("Hackatime API Connection Error: #{e.message}")
    nil
  end

  def get_user_projects(slack_id, start_date: nil)
    return [] unless slack_id.present?
    
    response = @conn.get("users/#{slack_id}/stats") do |req|
      req.params["features"] = "projects"
      req.params["start_date"] = start_date.to_s if start_date
    end

    unless response.success?
      Rails.logger.error("Hackatime stats API failed for #{slack_id}: #{response.status} - #{response.body}")
      return []
    end

    body = response.body || {}
    if body.dig("trust_factor", "trust_value") == 1
      Rails.logger.warn("User #{slack_id} is flagged as untrusted by Hackatime.")
      return []
    end

    projects_data = body.dig("data", "projects") || []
    projects = projects_data.map { |p| p.is_a?(Hash) ? p["name"] : p }.compact
    Rails.logger.info("Hackatime projects for #{slack_id}: #{projects.inspect}")
    projects
  rescue Faraday::Error => e
    Rails.logger.error("Hackatime API Connection Error for #{slack_id}: #{e.message}")
    []
  rescue => e
    Rails.logger.error("Unexpected error in get_user_projects for #{slack_id}: #{e.message}")
    []
  end

  def get_project_hours(slack_id, project_name, start_date: nil, end_date: nil)
    return 0.0 unless slack_id.present?
    
    response = @conn.get("users/#{slack_id}/stats") do |req|
      req.params["features"] = "projects"
      req.params["start_date"] = start_date.to_s if start_date
      req.params["end_date"] = end_date.to_s if end_date
      req.params["total_seconds"] = "true"
      req.params["filter_by_project"] = project_name
    end

    unless response.success?
      Rails.logger.warn("Hackatime API Request Failed for user #{slack_id}, project #{project_name}: #{response.status}")
      return 0.0
    end

    body = response.body || {}
    total_seconds = body["total_seconds"]
    
    unless total_seconds.is_a?(Numeric)
      Rails.logger.warn("Hackatime API returned non-numeric total_seconds for user #{slack_id}, project #{project_name}: #{total_seconds.inspect}")
      return 0.0
    end
    
    total_seconds / 3600.0
  rescue Faraday::Error => e
    Rails.logger.error("Hackatime API Connection Error for user #{slack_id}: #{e.message}")
    0.0
  rescue => e
    Rails.logger.error("Unexpected error in get_project_hours for user #{slack_id}: #{e.message}")
    0.0
  end
end
