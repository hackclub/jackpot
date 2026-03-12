# frozen_string_literal: true

class ReqItemController < ApplicationController
  ADMIN_ONLY = false

  before_action :authenticate_user!

  def index
    @show_req_item_form = !ADMIN_ONLY || admin?

    if @show_req_item_form
      @shop_item_request = current_user.shop_item_requests.build
      @last_request_at = current_user.shop_item_requests.maximum(:created_at)
      @next_allowed_on = @last_request_at.present? ? (@last_request_at.to_date + 14.days) : nil
      @can_submit = @next_allowed_on.nil? || Date.current >= @next_allowed_on

      week_start = Time.current.beginning_of_week
      week_end = Time.current.end_of_week
      @this_week_requests = ShopItemRequest.where(created_at: week_start..week_end).order(created_at: :asc)
    end
  end

  def create
    if ADMIN_ONLY && !admin?
      redirect_to req_item_path, alert: "Exchange Desk is not available yet."
      return
    end
    last_request_at = current_user.shop_item_requests.maximum(:created_at)
    next_allowed_on = last_request_at.present? ? (last_request_at.to_date + 14.days) : nil
    if next_allowed_on.present? && Date.current < next_allowed_on
      redirect_to req_item_path, alert: "You can only request one item every 2 weeks. Your next request is allowed on #{next_allowed_on.strftime('%A, %B %-d')}. Try again then."
      return
    end

    @shop_item_request = current_user.shop_item_requests.build(shop_item_request_params)
    if @shop_item_request.save
      redirect_to req_item_path, notice: "Your item request was submitted successfully! It cannot be edited or canceled."
    else
      @last_request_at = last_request_at
      @next_allowed_on = next_allowed_on
      @can_submit = next_allowed_on.nil? || Date.current >= next_allowed_on
      week_start = Time.current.beginning_of_week
      week_end = Time.current.end_of_week
      @this_week_requests = ShopItemRequest.where(created_at: week_start..week_end).order(created_at: :asc)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def shop_item_request_params
    params.require(:shop_item_request).permit(:item_name, :price, :reference_link)
  end
end

