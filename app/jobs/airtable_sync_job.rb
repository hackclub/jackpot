# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class AirtableSyncJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(rsvp_id)
    rsvp = RsvpTable.find_by(id: rsvp_id)
    return unless rsvp

    sync_log = AirtableSyncLog.create!(rsvp_table: rsvp, status: "pending")

    begin
      response = send_to_airtable(rsvp)

      sync_log.update!(
        status: response.code.to_i.between?(200, 299) ? "success" : "failed",
        response_code: response.code.to_i,
        response_body: response.body.truncate(5000),
        synced_at: Time.current
      )

      rsvp.update!(synced_at: Time.current) if sync_log.success?
    rescue StandardError => e
      sync_log.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}".truncate(5000)
      )
      raise # re-raise so ActiveJob retry logic kicks in
    end
  end

  private

  def send_to_airtable(rsvp)
    credentials = Rails.application.credentials.airtable
    base_id = credentials[:base_id]
    table_id = credentials[:_rsvp_table_id]
    token = credentials[:acces_token]

    uri = URI("https://api.airtable.com/v0/#{base_id}/#{table_id}")

    fields = {
      "email" => rsvp.email,
      "user_agent" => rsvp.user_agent
    }
    fields["ref"] = rsvp.ref if rsvp.ref.present?

    body = { fields: fields }.to_json

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request.body = body

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      http.request(request)
    end
  end
end
