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

    begin
      ensure_fields_exist
    rescue => e
      log("Field auto-creation error: #{e.class}: #{e.message}")
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

    if record.airtable_id.present?
      log("#{prefix}: updating airtable_id=#{record.airtable_id}")
      update_airtable_record(record, fields)
    else
      log("#{prefix}: creating new")
      create_airtable_record(record, fields)
    end

    record.update_column(synced_at_field, Time.current)
    log("#{prefix}: OK")
  rescue Norairrecord::Error => e
    log("#{prefix}: FAILED - #{e.class}: #{e.message}")
  rescue => e
    log("#{prefix}: FAILED - #{e.class}: #{e.message}")
  end

  def create_airtable_record(record, fields)
    airtable_record = table.new(fields)
    airtable_record.create
    record.update_column(:airtable_id, airtable_record.id)
  end

  def update_airtable_record(record, fields)
    airtable_record = table.find(record.airtable_id)
    fields.each { |key, value| airtable_record[key] = value }
    airtable_record.save
  rescue Norairrecord::RecordNotFoundError
    record.update_column(:airtable_id, nil)
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
    unless response.success?
      log("Metadata API failed: HTTP #{response.status} - #{response.body.to_s.truncate(500)}")
      return nil
    end

    tables = JSON.parse(response.body)["tables"] || []
    found = tables.find { |t| t["name"] == table_name }
    log("Table '#{table_name}' #{found ? 'found' : 'NOT FOUND'} in Airtable base")
    found
  end

  def ensure_fields_exist
    sample = records_to_sync.first
    return unless sample

    needed_fields = field_mapping(sample)
    table_meta = fetch_table_meta
    return unless table_meta

    existing_names = table_meta["fields"].map { |f| f["name"] }.to_set
    table_id = table_meta["id"]
    missing = needed_fields.keys.reject { |name| existing_names.include?(name) }

    if missing.empty?
      log("All #{needed_fields.size} fields exist")
      return
    end

    log("Creating #{missing.size} missing fields: #{missing.join(', ')}")

    missing.each do |name|
      value = needed_fields[name]
      field_def = { name: name, type: infer_airtable_type(value) }
      response = meta_connection.post("v0/meta/bases/#{base_id}/tables/#{table_id}/fields", field_def.to_json)

      if response.success?
        log("Created field '#{name}' (#{field_def[:type]})")
      else
        log("FAILED to create field '#{name}': #{response.body.to_s.truncate(300)}")
      end
    end
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
