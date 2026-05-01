class HackathonInfoController < ApplicationController
  def index
    @signup_goal = 25
    @signup_count = fetch_signup_count
    @hackathon_confirmed_count = fetch_hackathon_confirmed_count
  end

  private

  def fetch_signup_count
    AirtableSignupsCount.count.to_i
  rescue StandardError => e
    Rails.logger.error("HackathonInfoController#index signup: #{e.class}: #{e.message}")
    0
  end

  def fetch_hackathon_confirmed_count
    AirtableHackathonConfirmedParticipantsCount.count.to_i
  rescue StandardError => e
    Rails.logger.error("HackathonInfoController#index confirmed participants: #{e.class}: #{e.message}")
    0
  end
end
