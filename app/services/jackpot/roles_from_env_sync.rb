# frozen_string_literal: true

module Jackpot
  # Comma-separated emails in ENV; run `bin/rails jackpot:sync_roles_from_env` to apply.
  # If the same email appears in more than one list, the highest role wins:
  # reviewer < admin < super_admin.
  #
  #   JACKPOT_REVIEWER_EMAILS=a@x.com,b@x.com
  #   JACKPOT_ADMIN_EMAILS=...
  #   JACKPOT_SUPER_ADMIN_EMAILS=...
  class RolesFromEnvSync
    Result = Struct.new(:updated, :missing, :dry_run, keyword_init: true)

    ROLE_STEPS = [
      [ :reviewer, "JACKPOT_REVIEWER_EMAILS" ],
      [ :admin, "JACKPOT_ADMIN_EMAILS" ],
      [ :super_admin, "JACKPOT_SUPER_ADMIN_EMAILS" ]
    ].freeze

    def self.call(dry_run: false)
      new(dry_run: dry_run).call
    end

    def initialize(dry_run: false)
      @dry_run = dry_run
    end

    def call
      email_to_role = build_email_to_role
      updated = []
      missing = []

      email_to_role.each do |email, target_role|
        user = User.find_by("LOWER(email) = ?", email.downcase)
        if user.nil?
          missing << { email: email, role: target_role }
          next
        end

        next if user.role.to_sym == target_role

        if @dry_run
          updated << { user_id: user.id, email: user.email, from: user.role, to: target_role.to_s }
        else
          user.update!(role: target_role)
          updated << { user_id: user.id, email: user.email, from: user.role, to: target_role.to_s }
        end
      end

      Result.new(updated: updated, missing: missing, dry_run: @dry_run)
    end

    private

    def build_email_to_role
      h = {}
      ROLE_STEPS.each do |role, env_key|
        split_env(ENV[env_key]).each { |e| h[e.downcase] = role }
      end
      h
    end

    def split_env(raw)
      return [] if raw.blank?

      raw.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
