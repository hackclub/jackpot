# frozen_string_literal: true

class StatusController < ApplicationController
  before_action :authenticate_user!

  def index
    @show_status_content = true
    @projects = current_user.projects
      .includes(:reviewed_by, project_comments: :user)
      .order(
        Arel.sql("CASE WHEN projects.status = 'rejected' THEN 0 ELSE 1 END"),
        :position,
        created_at: :desc
      )
    @total_chips = current_user.chip_am.to_i
    @pending_orders = current_user.shop_orders.pending.order(created_at: :desc)
    @fulfilled_orders = current_user.shop_orders.sent.order(created_at: :desc)
    @rejected_orders = current_user.shop_orders.refunded.order(created_at: :desc)
  end
end
