class ShopItem < ApplicationRecord
  has_many :shop_orders, dependent: :nullify

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validate :safe_urls

  scope :active, -> { where(active: true) }

  private

  def safe_urls
    %i[item_link image_url].each do |attr|
      value = send(attr).to_s.strip
      next if value.blank?
      unless value.match?(/\Ahttps?:\/\//i)
        errors.add(attr, "must start with http:// or https://")
      end
    end
  end
end
