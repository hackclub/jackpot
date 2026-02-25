class CreateShopCategoriesAndGrantTypes < ActiveRecord::Migration[8.1]
  class MigrationShopCategory < ActiveRecord::Base
    self.table_name = "shop_categories"
  end

  class MigrationShopGrantType < ActiveRecord::Base
    self.table_name = "shop_grant_types"
  end

  class MigrationShopItem < ActiveRecord::Base
    self.table_name = "shop_items"
  end

  def up
    create_table :shop_categories do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.timestamps
    end

    add_index :shop_categories, :key, unique: true
    add_index :shop_categories, :name, unique: true

    create_table :shop_grant_types do |t|
      t.references :shop_category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.timestamps
    end

    add_index :shop_grant_types, %i[shop_category_id key], unique: true
    add_index :shop_grant_types, %i[shop_category_id name], unique: true

    add_reference :shop_items, :shop_grant_type, foreign_key: true

    # Seed initial structure and attach existing items to Generic → iPad/Tablet.
    generic = MigrationShopCategory.create!(name: "Generic", key: "generic")
    setup = MigrationShopCategory.create!(name: "Setup", key: "setup")
    hardware = MigrationShopCategory.create!(name: "Hardware", key: "hardware")

    ipad = MigrationShopGrantType.create!(shop_category_id: generic.id, name: "iPad / Tablet", key: "ipad_tablet")
    MigrationShopGrantType.create!(shop_category_id: generic.id, name: "Phones", key: "phones")

    MigrationShopGrantType.create!(shop_category_id: setup.id, name: "Gaming Chair", key: "gaming_chair")
    MigrationShopGrantType.create!(shop_category_id: setup.id, name: "Webcam", key: "webcam")

    MigrationShopGrantType.create!(shop_category_id: hardware.id, name: "3D Print", key: "print_3d")
    MigrationShopGrantType.create!(shop_category_id: hardware.id, name: "Drones", key: "drones")

    MigrationShopItem.where(shop_grant_type_id: nil).update_all(shop_grant_type_id: ipad.id)
    change_column_null :shop_items, :shop_grant_type_id, false
  end

  def down
    change_column_null :shop_items, :shop_grant_type_id, true
    remove_reference :shop_items, :shop_grant_type, foreign_key: true
    drop_table :shop_grant_types
    drop_table :shop_categories
  end
end

