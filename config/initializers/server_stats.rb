# frozen_string_literal: true

# Stores the server boot time and git version for the stats footer
Rails.application.config.server_start_time = Time.current

# Resolve the git commit SHA at boot (Kamal writes a REVISION file on deploy)
Rails.application.config.git_version = if File.exist?(Rails.root.join("REVISION"))
  File.read(Rails.root.join("REVISION")).strip[0..7]
else
  `git rev-parse --short HEAD 2>/dev/null`.strip.presence || "unknown"
end

# Track DB queries per request via ActiveSupport::Notifications
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  # Skip schema/explain queries and internal Rails bookkeeping
  name = payload[:name]
  next if name == "SCHEMA" || name == "EXPLAIN"

  Thread.current[:db_query_count] = (Thread.current[:db_query_count] || 0) + 1

  if payload[:cached]
    Thread.current[:db_cached_count] = (Thread.current[:db_cached_count] || 0) + 1
  end
end
