# frozen_string_literal: true

class ShopItemRequest < ApplicationRecord
  belongs_to :user

  validates :item_name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reference_link, presence: true
end
