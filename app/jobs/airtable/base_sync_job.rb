class Airtable::BaseSyncJob < ApplicationJob
  queue_as :literally_whenever

  attr_reader :sync_log

  def self.perform_later(*args)
    return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

    super
  end

  def perform
    @sync_log = []
    log("Starting #{self.class.name}")
    log("API token present: #{api_token.present?}")
    log("Base ID: #{base_id.presence || 'MISSING'}")
    log("Table name: #{table_name}")

    unless api_token.present? && base_id.present?
      log("ERROR: Missing Airtable credentials, aborting")
      return
    end

    to_sync = records_to_sync
    log("Records to sync: #{to_sync.size}")

    to_sync.each_with_index do |record, i|
      sync_single_record(record, i)
    end

    log("Finished #{self.class.name}")
  end

  private

  def log(msg)
    @sync_log ||= []
    entry = "[#{Time.current.strftime('%H:%M:%S')}] #{msg}"
    @sync_log << entry
    Rails.logger.info("AirtableSync: #{msg}")
  end

  def sync_single_record(record, index = nil)
    fields = field_mapping(record)
    prefix = "Record ##{record.id}"
    prefix += " (#{index + 1})" if index

    if record.send(airtable_id_field).present?
      log("#{prefix}: updating #{airtable_id_field}=#{record.send(airtable_id_field)}")
      update_airtable_record(record, fields)
    else
      log("#{prefix}: creating new")
      create_airtable_record(record, fields)
    end

    record.update_column(synced_at_field, Date.current)
    log("#{prefix}: OK")
  rescue Norairrecord::Error => e
    log("#{prefix}: FAILED - #{e.class}: #{e.message}")
  rescue => e
    log("#{prefix}: FAILED - #{e.class}: #{e.message}")
  end

  def create_airtable_record(record, fields)
    # Lock the row so concurrent workers can't both see airtable_id: nil and
    # each create a separate Airtable record for the same local record.
    record.with_lock do
      record.reload
      return update_airtable_record(record, fields) if record.send(airtable_id_field).present?

      airtable_record = table.new(fields)
      airtable_record.create
      record.update_column(airtable_id_field, airtable_record.id)
    end
  end

  def update_airtable_record(record, fields)
    airtable_record = table.find(record.send(airtable_id_field))
    fields.each { |key, value| airtable_record[key] = value }
    airtable_record.save
  rescue Norairrecord::RecordNotFoundError
    # The Airtable record was deleted externally; clear the stale ID and recreate.
    # Nil out first so create_airtable_record doesn't recurse back here.
    record.update_column(airtable_id_field, nil)
    record.reload
    create_airtable_record(record, fields)
  end

  def table_name
    raise NotImplementedError
  end

  def records
    raise NotImplementedError
  end

  def field_mapping(_record)
    raise NotImplementedError
  end

  def airtable_id_field
    :airtable_id
  end

  def synced_at_field
    :synced_at
  end

  def primary_key_field
    "flavor_id"
  end

  def sync_limit
    50
  end

  def null_sync_limit
    sync_limit
  end

  def records_to_sync
    @records_to_sync ||= if null_sync_limit == sync_limit
      records.order("#{synced_at_field} ASC NULLS FIRST").limit(sync_limit)
    else
      null_count = records.where(synced_at_field => nil).count
      if null_count >= sync_limit
        records.where(synced_at_field => nil).limit(null_sync_limit)
      else
        remaining = sync_limit - null_count
        null_sql = records.unscope(:includes).where(synced_at_field => nil).to_sql
        non_null_sql = records.unscope(:includes).where.not(synced_at_field => nil).order("#{synced_at_field} ASC").limit(remaining).to_sql
        records.unscope(:includes).from("(#{null_sql} UNION ALL #{non_null_sql}) AS #{records.table_name}")
      end
    end
  end

  def table
    @table ||= Norairrecord.table(api_token, base_id, table_name)
  end

  def api_token
    @api_token ||= Rails.application.credentials&.airtable&.acces_token || ENV["AIRTABLE_API_KEY"]
  end

  def base_id
    @base_id ||= Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"]
  end
end
