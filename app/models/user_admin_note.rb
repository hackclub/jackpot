# frozen_string_literal: true

class UserAdminNote < ApplicationRecord
  NOTE_TYPES = %w[general bolt_adjustment].freeze

  belongs_to :user
  belongs_to :author, class_name: "User"

  validates :note_type, inclusion: { in: NOTE_TYPES }
  validates :body, presence: true

  validate :bolt_fields_consistent

  scope :newest_first, -> { order(created_at: :desc) }

  def bolt_adjustment?
    note_type == "bolt_adjustment"
  end

  private

  def bolt_fields_consistent
    if bolt_adjustment?
      if chip_am_before.nil? || chip_am_after.nil?
        errors.add(:base, "Bolt adjustment requires before and after amounts")
      end
    elsif chip_am_before.present? || chip_am_after.present?
      errors.add(:base, "Chip amounts only allowed on bolt adjustment notes")
    end
  end
end
