# frozen_string_literal: true

class AddPriceUsdTotalSnapshotToShopOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :shop_orders, :price_usd_total_snapshot, :decimal, precision: 10, scale: 2

    ShopOrder.reset_column_information
    ShopOrder.includes(:shop_item).find_each do |o|
      next if o.read_attribute(:price_usd_total_snapshot).present?

      usd = (o.shop_item&.price_usd.to_d || 0) * o.quantity.to_i
      o.update_column(:price_usd_total_snapshot, usd) if usd.positive?
    end
  end

  def down
    remove_column :shop_orders, :price_usd_total_snapshot
  end
end
