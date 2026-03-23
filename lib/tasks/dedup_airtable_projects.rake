namespace :airtable do
  desc "Remove duplicate project records from Airtable, keeping the oldest record per name"
  task dedup_projects: :environment do
    api_token  = Rails.application.credentials&.airtable&.acces_token || ENV["AIRTABLE_API_KEY"]
    base_id    = Rails.application.credentials&.airtable&.base_id    || ENV["AIRTABLE_BASE_ID"]
    table_name = ENV.fetch("AIRTABLE_PROJECTS_TABLE", "_projects")

    unless api_token.present? && base_id.present?
      puts "ERROR: Missing AIRTABLE_API_KEY or AIRTABLE_BASE_ID"
      exit 1
    end

    puts "Fetching all records from Airtable table '#{table_name}'..."
    table = Norairrecord.table(api_token, base_id, table_name)

    all_records = table.all
    puts "Fetched #{all_records.size} records from Airtable."

    # Group by name to find duplicates (Airtable data only).
    groups = all_records.group_by { |r| r["Name"].to_s.strip.downcase }
    duplicated_groups = groups.select { |_name, records| records.size > 1 }
    puts "Found #{duplicated_groups.size} name(s) with duplicate Airtable records."

    if duplicated_groups.empty?
      puts "Nothing to clean up."
      next
    end

    total_deleted = 0

    duplicated_groups.each do |name, records|
      puts "\n  '#{name}' has #{records.size} records: #{records.map(&:id).join(', ')}"

      # Keep the oldest record (earliest created_time); it was the original.
      canonical = records.min_by { |r| r["Created At"].to_s }
      puts "    Keeping oldest record: #{canonical.id} (created #{canonical["Created At"]})"

      duplicates = records.reject { |r| r.id == canonical.id }
      duplicates.each do |dupe|
        puts "    Deleting duplicate: #{dupe.id} (created #{dupe["Created At"]})"
        begin
          dupe.destroy
          total_deleted += 1
        rescue Norairrecord::Error => e
          puts "    FAILED to delete #{dupe.id}: #{e.message}"
        end
      end
    end

    puts "\nDone. Deleted #{total_deleted} duplicate Airtable project record(s)."
  end
end
