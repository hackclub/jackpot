class Airtable::UserSyncJob < Airtable::BaseSyncJob
  def table_name
    ENV.fetch("AIRTABLE_USERS_TABLE", "_users")
  end

  def records
    User.all
  end

  def field_mapping(user, is_new_airtable_record: false)
    {
      "Email" => user.email,
      "Name" => user.display_name,
      "Slack ID" => user.slack_id,
      "Slack Username" => user.slack_username,
      "Role" => user.role,
      "chip_am" => user.chip_am.to_f,
      "user_id" => user.id,
      "Hackatime Hours" => user.hackatime_hours.to_f,
      "tut" => user.tutorial_completed,
      "Last Sign In" => user.last_sign_in_at&.iso8601,
      "Created At" => user.created_at&.iso8601
    }
  end
end
