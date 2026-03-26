# frozen_string_literal: true

require "test_helper"

class ShopItemTest < ActiveSupport::TestCase
  test "Shipping/Tax $ — max_shipping_usd_for_quantity is 60% of line item USD" do
    item = ShopItem.new(
      name: "Book",
      price: BigDecimal(10),
      price_usd: BigDecimal(5),
      dollar_per_hour: BigDecimal(25)
    )
    # 2 × $5 = $10 items → max shipping/tax $6
    assert_equal BigDecimal("6.00"), item.max_shipping_usd_for_quantity(2)
    assert_equal BigDecimal("3.00"), item.max_shipping_usd_for_quantity(1)
  end

  test "Shipping/Tax $ — shipping_chips_for_usd converts dollars to chips at catalog rate" do
    item = ShopItem.new(
      name: "Book",
      price: BigDecimal(10),
      price_usd: BigDecimal(5),
      dollar_per_hour: BigDecimal(25)
    )
    # $6 shipping → (6/25)*50 = 12 chips (ceil)
    assert_equal 12, item.shipping_chips_for_usd(BigDecimal(6))
    assert_equal 0, item.shipping_chips_for_usd(BigDecimal(0))
  end
end
