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
  rescue StandardError => e
    Rails.logger.warn "Could not initialize access flipper: #{e.message}"
  end
end
