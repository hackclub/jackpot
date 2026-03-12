class AddMaxPurchasePerPersonToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :max_per_person, :integer
    add_index :shop_items, :max_per_person
  end
end
