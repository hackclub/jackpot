class AddShippedAirtableIdToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :shipped_airtable_id, :string
    add_column :projects, :shipped_synced_at, :date
  end
end
