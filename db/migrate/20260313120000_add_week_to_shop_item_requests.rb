# frozen_string_literal: true

class AddWeekToShopItemRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :shop_item_requests, :week, :integer

    say_with_time "Backfilling week for existing shop_item_requests" do
      tz = ActiveSupport::TimeZone["America/New_York"]
      base_friday_start = tz.parse("2026-03-13 00:00")

      ShopItemRequest.reset_column_information
      ShopItemRequest.find_each do |req|
        created = req.created_at.in_time_zone(tz)
        week =
          if created < base_friday_start
            1
          else
            weeks_since = ((created - base_friday_start) / 1.week).floor
            weeks_since + 2
          end
        req.update_columns(week: week)
      end
    end
  end

  def down
    remove_column :shop_item_requests, :week
  end
end
