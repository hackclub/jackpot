# Reads the number of rows in the Airtable "Signups" table (or AIRTABLE_SIGNUPS_TABLE).
# Used for the hackathon signup progress bar. Cached to limit API usage.
class AirtableSignupsCount
  CACHE_KEY = "airtable_signups_row_count"
  CACHE_TTL = 2.minutes

  def self.count
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_count }
  rescue StandardError => e
    Rails.logger.warn("AirtableSignupsCount cache: #{e.class}: #{e.message}")
    fetch_count
  end

  def self.fetch_count
    token = airtable_api_token
    base_id = Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]
    return 0 if token.blank? || base_id.blank?

    table_name = ENV.fetch("AIRTABLE_SIGNUPS_TABLE", "Signups")
    tbl = Norairrecord.table(token, base_id, table_name)
    tbl.records.size
  rescue Norairrecord::Error => e
    Rails.logger.warn("AirtableSignupsCount: #{e.class}: #{e.message}")
    0
  rescue StandardError => e
    Rails.logger.error("AirtableSignupsCount: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    0
  end

  def self.airtable_api_token
    a = Rails.application.credentials&.airtable
    ENV["AIRTABLE_API_KEY"].presence ||
      a.try(:access_token).presence ||
      a.try(:acces_token).presence
  end
  private_class_method :airtable_api_token
end
