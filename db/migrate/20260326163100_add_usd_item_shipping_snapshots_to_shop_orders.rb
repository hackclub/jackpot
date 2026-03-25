# frozen_string_literal: true

class AddUsdItemShippingSnapshotsToShopOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :shop_orders, :price_usd_items_snapshot, :decimal, precision: 10, scale: 2
    add_column :shop_orders, :price_usd_shipping_snapshot, :decimal, precision: 10, scale: 2
    add_column :shop_orders, :shipping_chips_snapshot, :integer, default: 0, null: false

    ShopOrder.reset_column_information
    ShopOrder.find_each do |o|
      total = o.price_usd_total_snapshot
      next if total.blank?

      o.update_columns(
        price_usd_items_snapshot: total,
        price_usd_shipping_snapshot: 0,
        shipping_chips_snapshot: 0
      )
    end
  end

  def down
    remove_column :shop_orders, :shipping_chips_snapshot
    remove_column :shop_orders, :price_usd_shipping_snapshot
    remove_column :shop_orders, :price_usd_items_snapshot
  end
end
