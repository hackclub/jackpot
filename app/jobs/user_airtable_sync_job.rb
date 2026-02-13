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

    begin
      send_to_airtable(user)
    rescue StandardError => e
      Rails.logger.error "Airtable User Sync Failed for User #{user_id}: #{e.message}"
      raise
    end
  end

  private

  def send_to_airtable(user)
    credentials = Rails.application.credentials.airtable
    base_id = credentials[:base_id]
    
    table_id = credentials[:_users_table_id] || "tbl_users_placeholder" 
    token = credentials[:acces_token]

    if table_id == "tbl_users_placeholder"
      Rails.logger.warn "Missing airtable._users_table_id in credentials. Using placeholder."
    end

    uri = URI("https://api.airtable.com/v0/#{base_id}/#{table_id}")

    fields = {
      "Name" => user.name,
      "Email" => user.email,
      "chip_am" => user.chip_am.to_f,
      "projects" => user.projects.to_s 
    }

    body = { fields: fields }.to_json

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request.body = body

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      http.request(request)
    end
    
    unless response.code.to_i.between?(200, 299)
      raise "Airtable API Error: #{response.code} - #{response.body}"
    end
  end
end
