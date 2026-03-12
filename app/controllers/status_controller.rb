# frozen_string_literal: true

class StatusController < ApplicationController
  before_action :authenticate_user!

  def index
    @show_status_content = admin?
    return unless @show_status_content

    @projects = current_user.projects.includes(:reviewed_by, project_comments: :user).order(:position, created_at: :desc)
    @total_chips = current_user.chip_am.to_i
    @fulfilled_orders = current_user.shop_orders.sent.order(created_at: :desc)
    @rejected_orders = current_user.shop_orders.refunded.order(created_at: :desc)
  end
end
