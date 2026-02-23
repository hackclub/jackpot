# frozen_string_literal: true

class ShopController < ApplicationController
  ADMIN_ONLY = true

  before_action :authenticate_user!
  before_action :require_shop_feature
  before_action :require_admin_for_shop, if: -> { ADMIN_ONLY }

  def index
    @items = ShopItem.active.order(created_at: :desc)
  end

  def buy
    item = ShopItem.active.find(params[:id])
    quantity = [params[:quantity].to_i, 1].max
    total_cost = item.price * quantity

    ActiveRecord::Base.transaction do
      current_user.reload.lock!

      if current_user.chip_am.to_f < total_cost
        if request.xhr?
          return render json: { error: "Not enough chips! You need #{total_cost} but only have #{current_user.chip_am.to_f}." }, status: :unprocessable_entity
        else
          flash[:alert] = "Not enough chips!"
          return redirect_to shop_path
        end
      end

      current_user.update!(chip_am: current_user.chip_am.to_f - total_cost)

      current_user.shop_orders.create!(
        shop_item: item,
        item_name: item.name,
        user_email: current_user.email,
        slack_id: current_user.slack_id,
        quantity: quantity,
        price: total_cost,
        status: "pending"
      )
    end

    if request.xhr?
      render json: { success: true, new_balance: current_user.chip_am.to_f }
    else
      flash[:notice] = "Purchase successful!"
      redirect_to shop_path
    end
  rescue ActiveRecord::RecordNotFound
    if request.xhr?
      render json: { error: "Item not found or no longer available." }, status: :not_found
    else
      flash[:alert] = "Item not found."
      redirect_to shop_path
    end
  rescue => e
    Rails.logger.error("Shop purchase error: #{e.message}\n#{e.backtrace.join("\n")}")
    if request.xhr?
      render json: { error: "Something went wrong. Please try again." }, status: :internal_server_error
    else
      flash[:alert] = "Something went wrong."
      redirect_to shop_path
    end
  end

  private

  def require_admin_for_shop
    return if admin?

    respond_to do |format|
      format.html { render plain: "very, very, very soon...", status: :ok }
      format.json { render json: { error: "very, very, very soon..." }, status: :forbidden }
      format.any { render plain: "very, very, very soon...", status: :forbidden }
    end
  end

  def require_shop_feature
    return if Flipper.enabled?(:shop, current_user)

    redirect_to root_path, alert: "The shop is not available yet."
  end


end
