# frozen_string_literal: true

# Enqueues one Airtable row push per DB change (see AirtablePushOnChange). Avoids periodic full-table scans.
class Airtable::PushRecordJob < ApplicationJob
  queue_as :literally_whenever

  # Skip model after_commit enqueues while running a full-table sync or a single-row push (mirror saves fire callbacks).
  thread_mattr_accessor :suppress_enqueue

  discard_on ActiveRecord::RecordNotFound

  retry_on Norairrecord::Error, wait: :polynomially_longer, attempts: 5

  SYNC_JOB_TO_MODEL = {
    "Airtable::UserSyncJob" => User,
    "Airtable::ProjectSyncJob" => Project,
    "Airtable::RsvpSyncJob" => RsvpTable,
    "Airtable::ShopOrderSyncJob" => ShopOrder,
    "Airtable::ShopItemSyncJob" => ShopItem,
    "Airtable::JournalEntrySyncJob" => JournalEntry,
    "Airtable::ProjectCommentSyncJob" => ProjectComment,
    "Airtable::ShopItemRequestSyncJob" => ShopItemRequest,
    "Airtable::ShippedProjectSyncJob" => YswsProjectSubmission
  }.freeze

  class << self
    def without_enqueue
      prev = suppress_enqueue
      self.suppress_enqueue = true
      yield
    ensure
      self.suppress_enqueue = prev
    end

    def enqueue_if_configured(job_class, record_id)
      return if suppress_enqueue
      return if record_id.blank?
      return unless configured?

      perform_later(job_class.name, record_id)
    end

    def configured?
      token = Rails.application.credentials&.airtable&.acces_token || ENV["AIRTABLE_API_KEY"]
      base = Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]
      token.present? && base.present?
    end
  end

  def perform(sync_job_class_name, record_id)
    model_class = SYNC_JOB_TO_MODEL[sync_job_class_name]
    unless model_class
      Rails.logger.error("Airtable::PushRecordJob: unknown sync job #{sync_job_class_name.inspect}")
      return
    end

    sync_class = sync_job_class_name.constantize
    unless sync_class < Airtable::BaseSyncJob
      Rails.logger.error("Airtable::PushRecordJob: not a BaseSyncJob subclass #{sync_job_class_name}")
      return
    end

    record = model_class.find_by(id: record_id)
    return unless record

    sync_class.new.push_record!(record)
  end
end
