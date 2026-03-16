# frozen_string_literal: true

class CreateShopItemRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_item_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :item_name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :reference_link

      t.timestamps
    end
    add_index :shop_item_requests, [ :user_id, :created_at ]
  end
end
