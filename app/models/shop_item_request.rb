# frozen_string_literal: true

class ShopItemRequest < ApplicationRecord
  include AirtablePushOnChange

  belongs_to :user

  validates :item_name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reference_link, presence: true

  pushes_airtable_with Airtable::ShopItemRequestSyncJob

  before_validation :assign_week, on: :create

  def self.week_for_time(time)
    tz = ActiveSupport::TimeZone["America/New_York"]
    base_friday_start = tz.parse("2026-03-13 00:00")
    t = time.in_time_zone(tz)

    if t < base_friday_start
      1
    else
      weeks_since = ((t - base_friday_start) / 1.week).floor
      weeks_since + 2
    end
  end

  private

  def assign_week
    self.week ||= self.class.week_for_time(created_at || Time.current)
  end
end
