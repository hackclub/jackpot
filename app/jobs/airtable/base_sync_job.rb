class Airtable::BaseSyncJob < ApplicationJob
  queue_as :literally_whenever

  def self.perform_later(*args)
    return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

    super
  end

  # Syncs records to Airtable, creating new or updating existing.
  # Stores airtable_id on local records for future updates.
  def perform
    ensure_fields_exist
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

  def meta_connection
    @meta_connection ||= Faraday.new(
      url: "https://api.airtable.com",
      headers: {
        "Authorization" => "Bearer #{api_token}",
        "Content-Type" => "application/json"
      }
    )
  end

  def fetch_table_meta
    response = meta_connection.get("v0/meta/bases/#{base_id}/tables")
    return nil unless response.success?

    tables = JSON.parse(response.body)["tables"] || []
    tables.find { |t| t["name"] == table_name }
  end

  def ensure_fields_exist
    sample = records_to_sync.first
    return unless sample

    needed_fields = field_mapping(sample)
    table_meta = fetch_table_meta
    return unless table_meta

    existing_names = table_meta["fields"].map { |f| f["name"] }.to_set
    table_id = table_meta["id"]

    needed_fields.each do |name, value|
      next if existing_names.include?(name)

      field_def = { name: name, type: infer_airtable_type(value) }
      response = meta_connection.post("v0/meta/bases/#{base_id}/tables/#{table_id}/fields", field_def.to_json)

      if response.success?
        Rails.logger.info("Airtable: created field '#{name}' in #{table_name}")
      else
        Rails.logger.warn("Airtable: failed to create field '#{name}' in #{table_name}: #{response.body}")
      end
    end
  rescue => e
    Rails.logger.warn("Airtable: field auto-creation skipped: #{e.message}")
  end

  def infer_airtable_type(value)
    case value
    when TrueClass, FalseClass
      "checkbox"
    when Integer
      "number"
    when Float, BigDecimal
      "number"
    when /\A\d{4}-\d{2}-\d{2}T/
      "dateTime"
    else
      "singleLineText"
    end
  end
end