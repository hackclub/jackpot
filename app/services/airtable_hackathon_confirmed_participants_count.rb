# Counts Hackathon base rows where +notGoing+ is empty or explicitly false (e.g. unchecked checkbox).
# Config: AIRTABLE_HACKATHON_TABLE ("Hackathon"), AIRTABLE_HACKATHON_NOT_GOING_FIELD ("notGoing").
class AirtableHackathonConfirmedParticipantsCount
  CACHE_KEY = "airtable_hackathon_confirmed_participant_count"
  CACHE_TTL = 2.minutes
  COUNT_OFFSET = 5

  def self.count
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_count }
  rescue StandardError => e
    Rails.logger.warn("AirtableHackathonConfirmedParticipantsCount cache: #{e.class}: #{e.message}")
    fetch_count
  end

  def self.fetch_count
    token = airtable_api_token
    base_id = Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]
    return 0 if token.blank? || base_id.blank?

    table_name = ENV.fetch("AIRTABLE_HACKATHON_TABLE", "Hackathon")
    tbl = Norairrecord.table(token, base_id, table_name)
    field_name = ENV.fetch("AIRTABLE_HACKATHON_NOT_GOING_FIELD", "notGoing")
    formula = "OR(BLANK({#{field_name}}), {#{field_name}} = FALSE())"
    tbl.records(filter: formula).size + COUNT_OFFSET
  rescue Norairrecord::Error => e
    Rails.logger.warn("AirtableHackathonConfirmedParticipantsCount: #{e.class}: #{e.message}")
    0
  rescue StandardError => e
    Rails.logger.error(
      "AirtableHackathonConfirmedParticipantsCount: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    )
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
