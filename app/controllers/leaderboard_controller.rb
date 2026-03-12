# frozen_string_literal: true

class LeaderboardController < ApplicationController
  before_action :authenticate_user!

  PER_PAGE = 50
  SORT_OPTIONS = %w[chips hours].freeze

  def index
    @page = [params.fetch(:page, 1).to_i, 1].max
    @sort = params[:sort].presence_in(SORT_OPTIONS) || "chips"
    order_clause = @sort == "hours" ? { hackatime_hours: :desc } : { chip_am: :desc }
    @users = User.order(order_clause)
                 .limit(PER_PAGE)
                 .offset((@page - 1) * PER_PAGE)
    @total_count = User.count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
  end
end
