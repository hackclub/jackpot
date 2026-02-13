# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class UserAirtableSyncJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    sync_log = AirtableSyncLog.create!(syncable: user, status: "pending")

    begin
      response = send_to_airtable(user)

      sync_log.update!(
        status: response.code.to_i.between?(200, 299) ? "success" : "failed",
        response_code: response.code.to_i,
        response_body: response.body.truncate(5000),
        synced_at: Time.current
      )
    rescue StandardError => e
      sync_log.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}".truncate(5000)
      )
      raise
    end
  end

  private

  def send_to_airtable(user)
    credentials = Rails.application.credentials.airtable
    base_id = credentials[:base_id]
    table_id = credentials[:_users_table_id]
    token = credentials[:acces_token]

    projects_json = (user.projects || []).to_json

    fields = {
      "Name" => user.display_name,
      "Email" => user.email,
      "chip_am" => user.chip_am.to_f,
      "Projects" => projects_json
    }

    table_refs = [table_id, "_users"].compact.uniq
    last_response = nil

    table_refs.each do |table_ref|
      response = upsert_to_table(base_id, table_ref, token, user, fields)
      return response if response.code.to_i.between?(200, 299)

      last_response = response
      Rails.logger.warn("User Airtable sync failed for table_ref=#{table_ref}: #{response.code} #{response.body}")
    end

    raise "Airtable API Error: #{last_response&.code} - #{last_response&.body}"
  end

  def upsert_to_table(base_id, table_ref, token, user, fields)
    response = patch_by_record_id(base_id, table_ref, token, user.airtable_record_id, fields) if user.airtable_record_id.present?
    return response if response&.code.to_i&.between?(200, 299)

    found_record_id = find_record_id_by_email(base_id, table_ref, token, user.email)
    if found_record_id.present?
      user.update_column(:airtable_record_id, found_record_id)
      response = patch_by_record_id(base_id, table_ref, token, found_record_id, fields)
      return response if response.code.to_i.between?(200, 299)
    end

    create_response = create_record(base_id, table_ref, token, fields)
    if create_response.code.to_i.between?(200, 299)
      parsed = JSON.parse(create_response.body)
      user.update_column(:airtable_record_id, parsed["id"]) if parsed["id"].present?
    end
    create_response
  end

  def patch_by_record_id(base_id, table_ref, token, record_id, fields)
    uri = URI("https://api.airtable.com/v0/#{base_id}/#{table_ref}/#{record_id}")
    request = Net::HTTP::Patch.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request.body = { fields: fields }.to_json
    http_request(uri, request)
  end

  def create_record(base_id, table_ref, token, fields)
    uri = URI("https://api.airtable.com/v0/#{base_id}/#{table_ref}")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request.body = { fields: fields }.to_json
    http_request(uri, request)
  end

  def find_record_id_by_email(base_id, table_ref, token, email)
    escaped_email = email.to_s.gsub("'", "\\\\'")
    formula = "{Email}='#{escaped_email}'"
    uri = URI("https://api.airtable.com/v0/#{base_id}/#{table_ref}")
    uri.query = URI.encode_www_form(filterByFormula: formula, maxRecords: 1)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"

    response = http_request(uri, request)
    return nil unless response.code.to_i.between?(200, 299)

    parsed = JSON.parse(response.body)
    parsed.dig("records", 0, "id")
  rescue JSON::ParserError
    nil
  end

  def http_request(uri, request)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      http.request(request)
    end
  end
end
