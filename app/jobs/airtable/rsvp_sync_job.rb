class Airtable::RsvpSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_RSVPS_TABLE", "_rsvps")
  end

  def records
    RsvpTable.all
  end

  def field_mapping(rsvp, is_new_airtable_record: false)
    {
      "email" => rsvp.email,
      "user_agent" => rsvp.user_agent,
      "ip" => rsvp.ip,
      "ref" => rsvp.ref,
      "synced_at" => Time.current.iso8601
    }
  end
end
