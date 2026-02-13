class Airtable::BaseSyncJob < ApplicationJob
  queue_as :literally_whenever

  def self.perform_later(*args)
    return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

    super
  end

  # Syncs records to Airtable, creating new or updating existing.
  # Stores airtable_id on local records for future updates.
  def perform
    records_to_sync.each do |record|
      sync_single_record(record)
    end
  end

  private

  # Syncs a single record to Airtable.
  # Creates if no airtable_id, updates if airtable_id exists.
  def sync_single_record(record)
    fields = field_mapping(record)

    if record.airtable_id.present?
      update_airtable_record(record, fields)
    else
      create_airtable_record(record, fields)
    end

    record.update_column(synced_at_field, Time.current)
  rescue Norairrecord::Error => e
    Rails.logger.error("Airtable sync failed for #{record.class}##{record.id}: #{e.message}")
  end

  # Creates a new record in Airtable and stores the airtable_id locally.
  def create_airtable_record(record, fields)
    airtable_record = table.new(fields)
    airtable_record.create
    record.update_column(:airtable_id, airtable_record.id)
  end

  # Updates an existing Airtable record by its stored airtable_id.
  def update_airtable_record(record, fields)
    airtable_record = table.find(record.airtable_id)
    fields.each { |key, value| airtable_record[key] = value }
    airtable_record.save
  rescue Norairrecord::RecordNotFoundError
    # Record was deleted in Airtable, recreate it
    record.update_column(:airtable_id, nil)
    create_airtable_record(record, fields)
  end

  def table_name
    raise NotImplementedError, "Subclass must implement #table_name"
  end

  def records
    raise NotImplementedError, "Subclass must implement #records"
  end

  def field_mapping(_record)
    raise NotImplementedError, "Subclass must implement #field_mapping"
  end

  def synced_at_field
    :synced_at
  end

  def primary_key_field
    "flavor_id"
  end

  def sync_limit
    10
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
    @table ||= Norairrecord.table(
      Rails.application.credentials&.airtable&.acces_token || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      table_name
    )
  end
end