# frozen_string_literal: true

# Load configuration from Rails credentials
Rails.application.config.x.hack_club.client_id = Rails.application.credentials.hack_club.client_id
Rails.application.config.x.hack_club.client_secret = Rails.application.credentials.hack_club.client_secret
Rails.application.config.x.lockbox.master_key = Rails.application.credentials.lockbox_master_key
