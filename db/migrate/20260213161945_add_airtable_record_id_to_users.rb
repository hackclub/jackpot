class AddAirtableRecordIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :airtable_record_id, :string
  end
end
