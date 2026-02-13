class AddDetailsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :chip_am, :decimal, precision: 10, scale: 1, default: 0.0
    add_column :users, :projects, :jsonb, default: []
    add_column :users, :profile_photo_url, :string
  end
end
