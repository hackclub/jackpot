class ShopOrder < ApplicationRecord
  include AirtablePushOnChange

  belongs_to :user
  belongs_to :shop_item, optional: true

  validates :item_name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending sent refunded] }

  pushes_airtable_with Airtable::ShopOrderSyncJob

  scope :pending, -> { where(status: "pending") }
  scope :sent, -> { where(status: "sent") }
  scope :refunded, -> { where(status: "refunded") }
end
