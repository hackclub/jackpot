# frozen_string_literal: true

namespace :jackpot do
  desc "Apply staff roles from JACKPOT_*_EMAILS env vars (comma-separated). " \
       "Does not demote users who are not listed. Run after deploy or when .env changes."
  task sync_roles_from_env: :environment do
    dry = ENV["DRY_RUN"].present?

    rev = ENV["JACKPOT_REVIEWER_EMAILS"]
    adm = ENV["JACKPOT_ADMIN_EMAILS"]
    sup = ENV["JACKPOT_SUPER_ADMIN_EMAILS"]

    puts "ENV in this process (nil means unset here):"
    puts "  REVIEWER=#{rev.inspect}"
    puts "  ADMIN=#{adm.inspect}"
    puts "  SUPER_ADMIN=#{sup.inspect}"
    puts ""

    if [ rev, adm, sup ].all? { |v| v.blank? }
      puts "Nothing to do: all three JACKPOT_*_EMAILS are empty."
      puts "Add them in Coolify (production) or .env (dev: dotenv-rails loads .env automatically)."
      puts "Run this task on the same host as the app (e.g. Coolify exec) so those vars exist."
      puts "Or export in your shell: export JACKPOT_ADMIN_EMAILS=you@example.com"
      puts "\nUse DRY_RUN=1 to preview. Example: DRY_RUN=1 bin/rails jackpot:sync_roles_from_env"
    else
      result = Jackpot::RolesFromEnvSync.call(dry_run: dry)

      if result.updated.empty? && result.missing.empty?
        puts(dry ? "[DRY RUN] No changes needed." : "Updated 0 user(s): every listed email already has the target role.")
      else
        puts(dry ? "[DRY RUN] No database changes." : "Updated #{result.updated.size} user(s).")
      end

      result.updated.each do |row|
        puts "  - #{row[:email]} (id=#{row[:user_id]}): #{row[:from]} → #{row[:to]}"
      end

      if result.missing.any?
        puts "\nNo matching user in DB (email must match users.email exactly — check OAuth / Hack Club address):"
        result.missing.each { |m| puts "  - #{m[:email]} → #{m[:role]}" }
      end

      puts "\nSet DRY_RUN=1 to preview without saving." unless dry
    end
  end
end
