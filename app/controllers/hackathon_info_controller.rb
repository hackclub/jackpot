class HackathonInfoController < ApplicationController
  def index
    @signup_goal = 25
    @signup_count = AirtableSignupsCount.count.to_i
  rescue StandardError => e
    Rails.logger.error("HackathonInfoController#index: #{e.class}: #{e.message}")
    @signup_count = 0
  end
end
