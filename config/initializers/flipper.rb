# frozen_string_literal: true

# Flipper is configured automatically with the ActiveRecord adapter
# when flipper-active_record gem is loaded

require 'flipper/adapters/active_record'

# Ensure access flipper feature exists and is enabled globally by default
# This allows all existing users to continue accessing the app
Rails.application.config.after_initialize do
  begin
    # Skip Flipper setup if the tables haven't been created yet (e.g., during migrations)
    next unless ActiveRecord::Base.connection.table_exists?(:flipper_features)

    Flipper.enable(:access) unless Flipper.exist?(:access)

    # Shop and status page feature flags (disabled by default, enable per-user via Flipper UI)
    Flipper.add(:shop) unless Flipper.exist?(:shop)
    Flipper.add(:status) unless Flipper.exist?(:status)
  rescue StandardError => e
    Rails.logger.warn "Could not initialize access flipper: #{e.message}"
  end
end
