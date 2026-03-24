# frozen_string_literal: true

# Runs every Airtable table sync on a worker (not in the web request), so the admin "Force Sync" button
# does not hit gateway timeouts. Uses a raised per-batch limit so reconcile is not capped at 50 rows.
class Airtable::AdminForceSyncJob < ApplicationJob
  queue_as :literally_whenever

  SYNC_CLASSES = [
    Airtable::UserSyncJob,
    Airtable::ProjectSyncJob,
    Airtable::RsvpSyncJob,
    Airtable::ShopOrderSyncJob,
    Airtable::ShopItemSyncJob,
    Airtable::JournalEntrySyncJob,
    Airtable::ProjectCommentSyncJob,
    Airtable::ShopItemRequestSyncJob,
    Airtable::ShippedProjectSyncJob
  ].freeze

  def perform
    Thread.current[:airtable_admin_full_sync] = true
    YswsProjectSubmission.ensure_rows_for_shipped_projects!

    SYNC_CLASSES.each do |klass|
      klass.new.perform
    end
  ensure
    Thread.current[:airtable_admin_full_sync] = nil
  end
end
