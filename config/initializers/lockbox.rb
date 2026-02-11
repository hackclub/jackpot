# frozen_string_literal: true

Lockbox.master_key = ENV.fetch("LOCKBOX_MASTER_KEY") do
  if Rails.env.test?
    "0" * 64 # Test key - 64 bytes
  else
    Rails.application.credentials.lockbox_master_key
  end
end
