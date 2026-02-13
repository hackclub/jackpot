# frozen_string_literal: true

class LeaderboardController < ApplicationController
  before_action :authenticate_user!

  PER_PAGE = 50

  def index
    @page = [params.fetch(:page, 1).to_i, 1].max
    @users = User.order(chip_am: :desc)
                 .limit(PER_PAGE)
                 .offset((@page - 1) * PER_PAGE)
    @total_count = User.count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
  end
end
