# frozen_string_literal: true

class AirtableSyncLog < ApplicationRecord
  belongs_to :syncable, polymorphic: true

  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "pending") }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "failed") }
  scope :for_rsvps, -> { where(syncable_type: "RsvpTable") }
  scope :for_users, -> { where(syncable_type: "User") }

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
