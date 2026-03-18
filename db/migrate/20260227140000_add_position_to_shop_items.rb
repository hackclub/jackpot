# frozen_string_literal: true

class AddPositionToShopItems < ActiveRecord::Migration[8.0]
  def change
    add_column :shop_items, :position, :integer, default: 0, null: false
  end
end
