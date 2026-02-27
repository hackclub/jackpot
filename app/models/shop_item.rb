class ShopItem < ApplicationRecord
  PINNED_INVITATION_NAME = "Jackpot Official Invitation"

  has_many :shop_orders, dependent: :nullify
  belongs_to :shop_grant_type, optional: true
  has_one :shop_category, through: :shop_grant_type

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :price_usd, presence: true, numericality: { greater_than: 0 }, on: :create
  validates :dollar_per_hour, presence: true, numericality: { greater_than: 0 }, on: :create
  validates :max_per_person, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :grant_type_required_unless_pinned
  validate :safe_urls

  scope :active, -> { where(active: true) }

  before_validation :compute_price_from_usd
  before_validation :sync_category_and_grant_type

  def display_price
    p = price
    return "" if p.nil?
    s = p.to_d.to_s("F")
    s.sub(/\.0+\z/, "").sub(/(\.\d*?)0+\z/, '\1')
  end

  # Hours needed to purchase (price_usd / dollar_per_hour). Nil if not set.
  def hours_needed
    return nil if price_usd.blank? || dollar_per_hour.blank?
    return nil if dollar_per_hour.to_d.zero?
    (price_usd.to_d / dollar_per_hour.to_d).round(2)
  end

  def purchase_limit_reached_for?(user)
    return false if max_per_person.blank? || user.blank?
    purchased_quantity_for(user) >= max_per_person.to_i
  end

  def purchased_quantity_for(user)
    return 0 if user.blank?
    user.shop_orders.where(shop_item_id: id, status: %w[pending sent]).sum(:quantity).to_i
  end

  private

  def compute_price_from_usd
    return if price_usd.blank? || dollar_per_hour.blank?
    return if dollar_per_hour.to_d <= 0
    self.price = (price_usd.to_d / dollar_per_hour.to_d) * 50
  end

  def sync_category_and_grant_type
    if pinned_invitation?
      self.shop_grant_type_id = nil
      self.grant_type = nil
      self.category = nil
      return
    end

    self.grant_type = shop_grant_type&.name
    self.category = shop_category&.name
  end

  def pinned_invitation?
    name.to_s.strip.casecmp?(PINNED_INVITATION_NAME)
  end

  def grant_type_required_unless_pinned
    return if pinned_invitation?
    return if shop_grant_type.present?

    errors.add(:shop_grant_type, "must be selected")
  end

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
