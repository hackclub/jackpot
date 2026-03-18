class AddLogoUrlToShopGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_categories, :logo_url, :string
    add_column :shop_grant_types, :logo_url, :string
  end
end
