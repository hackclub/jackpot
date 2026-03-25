class ShopOrder < ApplicationRecord
  include AirtablePushOnChange

  belongs_to :user
  belongs_to :shop_item, optional: true

  # Snapshots at purchase: `item_name`, `price` (chips), `shipping_chips_snapshot`,
  # `price_usd_items_snapshot`, `price_usd_shipping_snapshot`, `price_usd_total_snapshot`.

  validates :item_name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending sent refunded] }

  pushes_airtable_with Airtable::ShopOrderSyncJob

  scope :pending, -> { where(status: "pending") }
  scope :sent, -> { where(status: "sent") }
  scope :refunded, -> { where(status: "refunded") }

  def usd_items_at_purchase
    read_attribute(:price_usd_items_snapshot).presence || price_usd_total_snapshot
  end

  def usd_shipping_at_purchase
    price_usd_shipping_snapshot.to_d
  end

  def usd_total_at_purchase
    price_usd_total_snapshot.to_d
  end

  # Multi-line copy for admin / status (amounts in USD at checkout).
  def usd_amount_description
    total = usd_total_at_purchase
    return "" if total.blank? || total <= 0

    items = usd_items_at_purchase.to_d
    ship = usd_shipping_at_purchase
    <<~TXT.strip
      Total: $#{format("%.2f", total.to_f)}
      Items-only: $#{format("%.2f", items.to_f)}
      Shipping: $#{format("%.2f", ship.to_f)}
    TXT
  end
end
