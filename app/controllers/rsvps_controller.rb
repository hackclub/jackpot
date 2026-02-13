# Handles RSVP creation for up to 4 emails per submission
class RsvpsController < ApplicationController
  skip_forgery_protection if: -> { Rails.env.development? }

  def create
    emails = Array(params[:emails]).reject(&:blank?)

    if emails.empty?
      render json: { error: "At least one email is required" }, status: :unprocessable_entity
      return
    end

    created = []
    errors = []

    emails.each do |email|
      rsvp = RsvpTable.new(
        email: email,
        ip: request.remote_ip,
        user_agent: request.user_agent,
        ref: params[:ref]
      )

      if rsvp.save
        created << rsvp
        AirtableSyncJob.perform_later(rsvp.id)
      else
        errors << { email: email, errors: rsvp.errors.full_messages }
      end
    end

    if errors.empty?
      render json: { success: true, message: "RSVP submitted successfully!", count: created.size }, status: :created
    else
      render json: { success: false, errors: errors, created_count: created.size }, status: :unprocessable_entity
    end
  end
end
