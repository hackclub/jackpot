# frozen_string_literal: true

# After create/update, enqueue a single-row Airtable push (Airtable::PushRecordJob) instead of relying on periodic full syncs.
module AirtablePushOnChange
  extend ActiveSupport::Concern

  class_methods do
    def pushes_airtable_with(job_class)
      @airtable_sync_job_class = job_class
      after_commit :airtable_push_after_create, on: :create
      after_commit :airtable_push_after_update, on: :update
    end

    def airtable_sync_job_class
      @airtable_sync_job_class
    end
  end

  def airtable_push_after_create
    airtable_enqueue_push
  end

  def airtable_push_after_update
    return unless airtable_push_meaningful_changes?

    airtable_enqueue_push
  end

  def airtable_push_meaningful_changes?
    keys = previous_changes.keys.map(&:to_sym)
    noise = %i[updated_at]
    noise << :last_sign_in_at if is_a?(User)
    (keys - noise).any?
  end

  def airtable_enqueue_push
    jc = self.class.airtable_sync_job_class
    return unless jc

    Airtable::PushRecordJob.enqueue_if_configured(jc, id)
  end
end
