# Model for storing RSVP submissions with email validation
class RsvpTable < ApplicationRecord
  has_many :airtable_sync_logs, as: :syncable, dependent: :destroy

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
end
