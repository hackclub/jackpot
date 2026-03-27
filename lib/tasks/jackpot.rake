# frozen_string_literal: true

namespace :jackpot do
  desc "Apply staff roles from JACKPOT_*_EMAILS env vars (comma-separated). " \
       "Does not demote users who are not listed. Run after deploy or when .env changes."
  task sync_roles_from_env: :environment do
    dry = ENV["DRY_RUN"].present?
    result = Jackpot::RolesFromEnvSync.call(dry_run: dry)

    puts(dry ? "[DRY RUN] No database changes." : "Updated #{result.updated.size} user(s).")

    result.updated.each do |row|
      puts "  - #{row[:email]} (id=#{row[:user_id]}): #{row[:from]} → #{row[:to]}"
    end

    if result.missing.any?
      puts "\nNo matching user (fix typo or wait until they sign in):"
      result.missing.each { |m| puts "  - #{m[:email]} (#{m[:role]})" }
    end

    puts "\nSet DRY_RUN=1 to preview without saving." unless dry
  end
end
