# Syncs RSVPs to Airtable from the local database.
# Pushes RSVP data for external tracking/reporting.
class Airtable::RsvpSyncJob < Airtable::BaseSyncJob
  # @return [String] Airtable table name
  def table_name
    ENV.fetch("AIRTABLE_RSVPS_TABLE", "_rsvps")
  end

  # @return [ActiveRecord::Relation] all RsvpTable records
  def records
    RsvpTable.all
  end

  # Maps RsvpTable attributes to Airtable fields.
  # @param rsvp [RsvpTable] the RSVP to map
  # @return [Hash] Airtable field values
  def field_mapping(rsvp)
    {
      "email" => rsvp.email,
      "user_agent" => rsvp.user_agent,
      "ref" => rsvp.ref
    }
  end
end
