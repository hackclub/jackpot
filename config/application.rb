require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Jackpot
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Tutorial: true = show on every login; false = only first time (default)
    config.x.tutorial_on_every_login = false

    # Track per-request cache hits and misses via ActiveSupport::Notifications
    ActiveSupport::Notifications.subscribe("cache_read.active_support") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      if event.payload[:hit]
        Thread.current[:cache_hits] += 1
      else
        Thread.current[:cache_misses] += 1
      end
    end

    ActiveSupport::Notifications.subscribe("cache_fetch_hit.active_support") do |*args|
      Thread.current[:cache_hits] += 1
    end
  end
end
