# Reads the number of rows in the Airtable "Signups" table (or AIRTABLE_SIGNUPS_TABLE).
# Used for the hackathon signup progress bar. Cached to limit API usage.
class AirtableSignupsCount
  CACHE_KEY = "airtable_signups_row_count"
  CACHE_TTL = 2.minutes

  def self.count
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_count }
  end

  def self.fetch_count
    token = Rails.application.credentials&.airtable&.acces_token || ENV["AIRTABLE_API_KEY"]
    base_id = Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]
    return 0 if token.blank? || base_id.blank?

    table_name = ENV.fetch("AIRTABLE_SIGNUPS_TABLE", "Signups")
    tbl = Norairrecord.table(token, base_id, table_name)
    tbl.records.size
  rescue Norairrecord::Error => e
    Rails.logger.warn("AirtableSignupsCount: #{e.class}: #{e.message}")
    0
  end
end
