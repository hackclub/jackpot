# frozen_string_literal: true

class BackfillWeekOnShopItemRequests < ActiveRecord::Migration[8.1]
  def up
    say_with_time "backfill shop_item_requests.week from created_at" do
      ShopItemRequest.where(week: nil).find_each do |r|
        w = ShopItemRequest.week_for_time(r.created_at)
        r.update_column(:week, w)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
