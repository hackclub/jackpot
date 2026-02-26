class AddCategoryAndGrantTypeToShopItems < ActiveRecord::Migration[8.1]
  def up
    add_column :shop_items, :category, :string unless column_exists?(:shop_items, :category)
    add_column :shop_items, :grant_type, :string unless column_exists?(:shop_items, :grant_type)

    execute <<~SQL
      UPDATE shop_items si
      SET
        category = sc.name,
        grant_type = sgt.name
      FROM shop_grant_types sgt
      JOIN shop_categories sc ON sc.id = sgt.shop_category_id
      WHERE si.shop_grant_type_id = sgt.id
    SQL
  end

  def down
    remove_column :shop_items, :grant_type if column_exists?(:shop_items, :grant_type)
    remove_column :shop_items, :category if column_exists?(:shop_items, :category)
  end
end

