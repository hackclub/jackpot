# Syncs users to Airtable from the local database.
# Pushes user data for external reporting/management.
class Airtable::UserSyncJob < Airtable::BaseSyncJob
  # @return [String] Airtable table name
  def table_name
    ENV.fetch("AIRTABLE_USERS_TABLE", "_users")
  end

  # @return [ActiveRecord::Relation] all User records
  def records
    User.all
  end

  # Maps User attributes to Airtable fields.
  # @param user [User] the user to map
  # @return [Hash] Airtable field values
  def field_mapping(user)

    {
      "Email" => user.email,
      "Name" => user.display_name,
      "Slack ID" => user.slack_id,
      "Slack Username" => user.slack_username,
      "Role" => user.role,
      "chip_am" => user.chip_am.to_f,
      "Hackatime Hours" => user.hackatime_hours.to_f,
      "tut" => user.tutorial_completed,
      "Last Sign In" => user.last_sign_in_at&.iso8601,
      "Created At" => user.created_at&.iso8601
    }
  end
end
