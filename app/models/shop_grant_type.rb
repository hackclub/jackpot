# frozen_string_literal: true

class ShopGrantType < ApplicationRecord
  belongs_to :shop_category
  has_many :shop_items, dependent: :restrict_with_error
  has_many :active_shop_items, -> { active }, class_name: "ShopItem"

  validates :name, presence: true, uniqueness: { scope: :shop_category_id, case_sensitive: false }
  validates :key, presence: true, uniqueness: { scope: :shop_category_id, case_sensitive: false }

  before_validation :ensure_key

  private

  def ensure_key
    self.key = name.to_s.parameterize(separator: "_") if key.blank? && name.present?
  end
end

