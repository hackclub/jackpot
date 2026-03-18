# frozen_string_literal: true

# Load configuration from Rails credentials (falls back to env vars for CI/test)
begin
  Rails.application.config.x.hack_club.client_id = Rails.application.credentials.dig(:hack_club, :client_id)
  Rails.application.config.x.hack_club.client_secret = Rails.application.credentials.dig(:hack_club, :client_secret)
  Rails.application.config.x.lockbox.master_key = Rails.application.credentials.lockbox_master_key
rescue ArgumentError
  Rails.application.config.x.hack_club.client_id = ENV["HACK_CLUB_CLIENT_ID"]
  Rails.application.config.x.hack_club.client_secret = ENV["HACK_CLUB_CLIENT_SECRET"]
  Rails.application.config.x.lockbox.master_key = ENV["LOCKBOX_MASTER_KEY"]
end
