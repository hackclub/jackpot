class CreateShopOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_orders do |t|
      t.bigint :user_id, null: false
      t.string :user_email
      t.string :slack_id
      t.string :item_name, null: false
      t.integer :quantity, default: 1, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :status, default: "pending", null: false
      t.bigint :shop_item_id

      t.timestamps
    end
    add_foreign_key :shop_orders, :users
    add_foreign_key :shop_orders, :shop_items
    add_index :shop_orders, :user_id
    add_index :shop_orders, :shop_item_id
  end
end
