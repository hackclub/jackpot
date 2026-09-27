# frozen_string_literal: true

require "test_helper"

class ShopItemRequestTest < ActiveSupport::TestCase
  test "reference_link must be an http(s) URL" do
    request = ShopItemRequest.new(item_name: "Mouse", price: 20, reference_link: "javascript:alert(document.cookie)")
    request.validate
    assert_includes request.errors[:reference_link], "must start with http:// or https://"

    request.reference_link = "https://example.com/mouse"
    request.validate
    assert_empty request.errors[:reference_link]
  end
end
