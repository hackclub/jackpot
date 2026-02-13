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
    project_names = (user.projects || []).map { |p| p["name"] }.compact.join(", ")

    {
      "Email" => user.email,
      "Name" => user.display_name,
      "chip_am" => user.chip_am.to_f,
      "Projects" => project_names
    }
  end
end
