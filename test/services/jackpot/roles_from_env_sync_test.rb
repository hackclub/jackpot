# frozen_string_literal: true

require "test_helper"

module Jackpot
  class RolesFromEnvSyncTest < ActiveSupport::TestCase
    setup do
      @prev = {
        "JACKPOT_REVIEWER_EMAILS" => ENV["JACKPOT_REVIEWER_EMAILS"],
        "JACKPOT_ADMIN_EMAILS" => ENV["JACKPOT_ADMIN_EMAILS"],
        "JACKPOT_SUPER_ADMIN_EMAILS" => ENV["JACKPOT_SUPER_ADMIN_EMAILS"]
      }
      ENV["JACKPOT_REVIEWER_EMAILS"] = nil
      ENV["JACKPOT_ADMIN_EMAILS"] = nil
      ENV["JACKPOT_SUPER_ADMIN_EMAILS"] = nil
    end

    teardown do
      @prev.each { |k, v| ENV[k] = v }
    end

    test "assigns highest role when email appears in multiple lists" do
      u = User.create!(
        hack_club_id: "sync_test_hc",
        email: "sync_roles_test@example.com",
        access_token: "t",
        role: :user
      )

      ENV["JACKPOT_REVIEWER_EMAILS"] = "sync_roles_test@example.com"
      ENV["JACKPOT_SUPER_ADMIN_EMAILS"] = "sync_roles_test@example.com"

      RolesFromEnvSync.call(dry_run: false)
      assert_equal "super_admin", u.reload.role

      ENV["JACKPOT_REVIEWER_EMAILS"] = nil
      ENV["JACKPOT_SUPER_ADMIN_EMAILS"] = nil
      u.update!(role: :user)
    end
  end
end
