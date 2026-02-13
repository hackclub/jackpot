class RemoveAirtableSyncInfrastructure < ActiveRecord::Migration[8.1]
  def change
    drop_table :airtable_sync_logs do |t|
      t.datetime :created_at, null: false
      t.text :error_message
      t.text :response_body
      t.integer :response_code
      t.string :status, default: "pending", null: false
      t.bigint :syncable_id
      t.string :syncable_type
      t.datetime :synced_at
      t.datetime :updated_at, null: false
      t.index [:syncable_type, :syncable_id], name: "index_airtable_sync_logs_on_syncable_type_and_syncable_id"
    end

    remove_column :users, :airtable_record_id, :string
  end
end
