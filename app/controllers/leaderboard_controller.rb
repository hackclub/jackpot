# frozen_string_literal: true

class LeaderboardController < ApplicationController
  before_action :authenticate_user!

  PER_PAGE = 50
  SORT_OPTIONS = %w[chips hours].freeze

  # Hackatime totals stored on projects + journal hours (all projects, any ship/review state).
  LOGGED_HOURS_TOTAL_SQL = <<~SQL.squish.freeze
    (
      COALESCE((SELECT SUM(projects.hackatime_hours::numeric) FROM projects WHERE projects.user_id = users.id), 0)
      + COALESCE((SELECT SUM(journal_entries.hours_worked) FROM journal_entries WHERE journal_entries.user_id = users.id), 0)
    )
  SQL

  def index
    @page = [ params.fetch(:page, 1).to_i, 1 ].max
    @sort = params[:sort].presence_in(SORT_OPTIONS) || "chips"
    scope = User.select("#{User.table_name}.*, #{LOGGED_HOURS_TOTAL_SQL} AS logged_hours_total")
    scope = if @sort == "hours"
              scope.order(Arel.sql("logged_hours_total DESC NULLS LAST, #{User.table_name}.id ASC"))
    else
              scope.order(chip_am: :desc, id: :asc)
    end
    @users = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
    @total_count = User.count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
  end
end
