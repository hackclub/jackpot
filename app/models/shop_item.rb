class ShopItem < ApplicationRecord
  has_many :shop_orders, dependent: :nullify

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
end
