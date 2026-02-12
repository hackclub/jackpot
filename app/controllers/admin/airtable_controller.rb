# frozen_string_literal: true

class Admin::AirtableController < ApplicationController
  skip_before_action :check_access_flipper
  before_action :authenticate_admin!

  PER_PAGE = 50

  def index
    @page = [ params.fetch(:page, 1).to_i, 1 ].max
    @sync_logs = AirtableSyncLog.includes(:rsvp_table)
                                .recent
                                .limit(PER_PAGE)
                                .offset((@page - 1) * PER_PAGE)
    @total_count = AirtableSyncLog.count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
  end

  private

  def authenticate_admin!
    redirect_to root_path unless admin?
  end
end
