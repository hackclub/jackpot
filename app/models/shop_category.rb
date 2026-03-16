# frozen_string_literal: true

class ShopCategory < ApplicationRecord
  has_many :shop_grant_types, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validate :safe_logo_url

  before_validation :ensure_key

  private

  def ensure_key
    self.key = name.to_s.parameterize(separator: "_") if key.blank? && name.present?
  end

  def safe_logo_url
    return if logo_url.to_s.strip.blank?
    return if logo_url.to_s.match?(/\Ahttps?:\/\//i)

    errors.add(:logo_url, "must start with http:// or https://")
  end
end
