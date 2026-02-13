class AddAirtableIdToRsvpTablesAndUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :rsvp_tables, :airtable_id, :string
    add_column :users, :airtable_id, :string
    add_column :users, :synced_at, :date
  end
end
