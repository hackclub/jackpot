# frozen_string_literal: true

class AddPriceUsdAndDollarPerHourToShopItems < ActiveRecord::Migration[8.0]
  def change
    add_column :shop_items, :price_usd, :decimal, precision: 10, scale: 2
    add_column :shop_items, :dollar_per_hour, :decimal, precision: 10, scale: 2
  end
end
