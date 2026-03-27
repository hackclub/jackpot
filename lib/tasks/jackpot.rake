# frozen_string_literal: true

namespace :jackpot do
  desc "Apply staff roles from JACKPOT_*_EMAILS env vars (comma-separated). " \
       "Does not demote users who are not listed. Run after deploy or when .env changes."
  task sync_roles_from_env: :environment do
    dry = ENV["DRY_RUN"].present?

    puts "Environment seen by this process (must be non-nil on the host that runs this task):"
    puts "  JACKPOT_REVIEWER_EMAILS=#{ENV['JACKPOT_REVIEWER_EMAILS'].inspect}"
    puts "  JACKPOT_ADMIN_EMAILS=#{ENV['JACKPOT_ADMIN_EMAILS'].inspect}"
    puts "  JACKPOT_SUPER_ADMIN_EMAILS=#{ENV['JACKPOT_SUPER_ADMIN_EMAILS'].inspect}"
    puts ""

    result = Jackpot::RolesFromEnvSync.call(dry_run: dry)

    listed = [
      ENV["JACKPOT_REVIEWER_EMAILS"],
      ENV["JACKPOT_ADMIN_EMAILS"],
      ENV["JACKPOT_SUPER_ADMIN_EMAILS"]
    ].compact.join(",").strip

    if listed.blank?
      puts "Nothing to do: all JACKPOT_*_EMAILS are empty. Set them in Coolify (or .env) and run this again on the same machine."
      puts "Tip: Coolify env is only available inside the deployed container — run this via Coolify exec / SSH to the app, not on your laptop unless you export the vars."
    elsif result.updated.empty? && result.missing.empty?
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
