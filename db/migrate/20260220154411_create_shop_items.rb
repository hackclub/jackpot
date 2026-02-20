class CreateShopItems < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_items do |t|
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :item_link
      t.string :image_url
      t.text :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
