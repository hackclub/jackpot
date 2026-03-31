class HackathonInfoController < ApplicationController
  def index
    @signup_goal = 25
    @signup_count = AirtableSignupsCount.count
  end
end
