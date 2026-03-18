class AddAirtableSyncToRemainingTables < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_orders, :airtable_id, :string
    add_column :shop_orders, :synced_at, :date
    add_column :shop_items, :airtable_id, :string
    add_column :shop_items, :synced_at, :date
    add_column :journal_entries, :airtable_id, :string
    add_column :journal_entries, :synced_at, :date
    add_column :project_comments, :airtable_id, :string
    add_column :project_comments, :synced_at, :date
    add_column :shop_item_requests, :airtable_id, :string
    add_column :shop_item_requests, :synced_at, :date
  end
end
