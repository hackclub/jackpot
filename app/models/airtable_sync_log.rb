# frozen_string_literal: true

class AirtableSyncLog < ApplicationRecord
  belongs_to :rsvp_table

  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "pending") }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "failed") }

  def success?
    status == "success"
  end

  def failed?
    status == "failed"
  end

  def pending?
    status == "pending"
  end
end
