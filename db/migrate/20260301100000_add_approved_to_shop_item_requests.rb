# frozen_string_literal: true

class AddApprovedToShopItemRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_item_requests, :approved, :boolean, default: false, null: false
  end
end
