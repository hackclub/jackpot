class ConvertAirtableSyncLogsToPolymorphic < ActiveRecord::Migration[8.1]
  def up
    add_column :airtable_sync_logs, :syncable_type, :string
    add_column :airtable_sync_logs, :syncable_id, :bigint

    execute "UPDATE airtable_sync_logs SET syncable_type = 'RsvpTable', syncable_id = rsvp_table_id"

    add_index :airtable_sync_logs, [ :syncable_type, :syncable_id ]

    remove_foreign_key :airtable_sync_logs, :rsvp_tables if foreign_key_exists?(:airtable_sync_logs, :rsvp_tables)
    remove_column :airtable_sync_logs, :rsvp_table_id
  end

  def down
    add_reference :airtable_sync_logs, :rsvp_table, null: false, foreign_key: true

    execute "UPDATE airtable_sync_logs SET rsvp_table_id = syncable_id WHERE syncable_type = 'RsvpTable'"

    remove_index :airtable_sync_logs, [ :syncable_type, :syncable_id ]
    remove_column :airtable_sync_logs, :syncable_type
    remove_column :airtable_sync_logs, :syncable_id
  end
end
