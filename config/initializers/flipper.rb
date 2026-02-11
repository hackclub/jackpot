# frozen_string_literal: true

# Configure Flipper
Flipper.configure do |config|
  config.default { Flipper.new(Flipper::Adapters::ActiveRecord.new) }
end
