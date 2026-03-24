# Model for storing RSVP submissions with email validation
class RsvpTable < ApplicationRecord
  include AirtablePushOnChange

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  pushes_airtable_with Airtable::RsvpSyncJob
end
