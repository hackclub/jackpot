# frozen_string_literal: true

# Deletes this model's row in the Airtable table used by the matching BaseSyncJob, when +airtable_id+ is set.
# Credentials match YswsProjectSubmission.airtable_api_credentials.
module AirtableSyncedRowDeletion
  extend ActiveSupport::Concern

  class_methods do
    # e.g. ENV.fetch("AIRTABLE_PROJECTS_TABLE", "_projects")
    def airtable_sync_table_name
      raise NotImplementedError, "#{name} must implement .airtable_sync_table_name"
    end
  end

  def delete_remote_airtable_record!
    aid = airtable_id
    return if aid.blank?

    token, base_id = YswsProjectSubmission.airtable_api_credentials
    unless token.present? && base_id.present?
      if Rails.env.production?
        raise StandardError, "Airtable is not configured; cannot remove synced record #{aid.inspect} from Airtable."
      end
      Rails.logger.warn(
        "#{self.class.name}##{id}: skip Airtable delete for #{aid.inspect} — credentials missing (non-production)"
      )
      return
    end

    tbl = Norairrecord.table(token, base_id, self.class.airtable_sync_table_name)
    rec = tbl.find(aid)
    rec.destroy
    Rails.logger.info("#{self.class.name}##{id}: deleted Airtable record #{aid}")
  rescue Norairrecord::RecordNotFoundError
    Rails.logger.info("#{self.class.name}##{id}: Airtable record #{aid} already gone (404)")
  rescue Norairrecord::Error => e
    Rails.logger.error("#{self.class.name}##{id}: Airtable delete failed: #{e.class}: #{e.message}")
    raise
  end
end
