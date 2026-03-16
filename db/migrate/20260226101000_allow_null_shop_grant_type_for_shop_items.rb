class AllowNullShopGrantTypeForShopItems < ActiveRecord::Migration[8.1]
  def change
    change_column_null :shop_items, :shop_grant_type_id, true
  end
end
