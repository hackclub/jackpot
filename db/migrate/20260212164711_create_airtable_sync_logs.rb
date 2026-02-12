class CreateAirtableSyncLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :airtable_sync_logs do |t|
      t.references :rsvp_table, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.integer :response_code
      t.text :response_body
      t.text :error_message
      t.datetime :synced_at

      t.timestamps
    end
  end
end
