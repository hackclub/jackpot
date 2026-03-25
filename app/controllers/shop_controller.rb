# frozen_string_literal: true

class ShopController < ApplicationController
  ADMIN_ONLY = false
  PINNED_ITEM_NAME = ShopItem::PINNED_INVITATION_NAME

  before_action :authenticate_user!
  before_action :require_admin_for_shop, if: -> { ADMIN_ONLY }
  before_action :require_shop_feature

  def index
    @shop_purchases_locked = shop_purchases_locked?
    @pinned_item = ShopItem.active.find_by(name: PINNED_ITEM_NAME)
    @purchased_qty_by_item_id = current_user.shop_orders
      .where(status: %w[pending sent])
      .where.not(shop_item_id: nil)
      .group(:shop_item_id)
      .sum(:quantity)

    raw_categories = ShopCategory.includes(shop_grant_types: :shop_items).order(:id)

    # Only show categories/grant types that have at least one ACTIVE item.
    @shop_categories = raw_categories.map do |cat|
      grant_types = cat.shop_grant_types.sort_by { |gt| gt.name.to_s.downcase }.map do |gt|
        active_items = gt.shop_items
          .select(&:active?)
          .reject { |it| it.name.to_s.strip.casecmp?(PINNED_ITEM_NAME) }
          .sort_by { |it| [ it.position.to_i, -(it.created_at.to_i) ] }
        next if active_items.empty?
        { grant_type: gt, items: active_items }
      end.compact

      next if grant_types.empty?
      { category: cat, grant_types: grant_types }
    end.compact
  end

  def buy
    if shop_purchases_locked?
      msg = "Hey! It looks like you're trying to purchase something, well... this function is now under maintenance. It will be available again soon!"
      if request.xhr?
        return render json: { error: msg }, status: :service_unavailable
      else
        flash[:alert] = msg
        return redirect_to shop_path
      end
    end

    item = ShopItem.active.find(params[:id])
    quantity = params[:quantity].to_i
    quantity = 1 if quantity < 1
    shipping_chips = params[:shipping_chips].presence || params[:shipping]
    shipping_chips = shipping_chips.to_i
    shipping_chips = 0 if shipping_chips.negative?
    shipping_chips = [ shipping_chips, 500_000 ].min

    unit_price = item.price.to_d.ceil
    total_cost = (unit_price * quantity).to_d + shipping_chips.to_d
    already = current_user.shop_orders.where(shop_item_id: item.id, status: %w[pending sent]).sum(:quantity).to_i
    if item.max_per_person.present? && (already + quantity) > item.max_per_person.to_i
      remaining = [ item.max_per_person.to_i - already, 0 ].max
      msg = remaining.zero? ? "Purchase limit reached for this item." : "You can only purchase #{remaining} more of this item."
      if request.xhr?
        return render json: { error: msg }, status: :unprocessable_entity
      else
        flash[:alert] = msg
        return redirect_to shop_path
      end
    end

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

      current_user.update!(chip_am: current_user.chip_am.to_d - total_cost)

      items_usd = item.price_usd.to_d * quantity
      shipping_usd =
        if shipping_chips.positive? && item.dollar_per_hour.present? && item.dollar_per_hour.to_d.positive?
          ((shipping_chips.to_d / 50) * item.dollar_per_hour.to_d).round(2)
        else
          0.to_d
        end
      total_usd = (items_usd + shipping_usd).round(2)

      current_user.shop_orders.create!(
        shop_item: item,
        item_name: item.name,
        user_email: current_user.email,
        slack_id: current_user.slack_id,
        quantity: quantity,
        price: total_cost,
        shipping_chips_snapshot: shipping_chips,
        price_usd_items_snapshot: items_usd,
        price_usd_shipping_snapshot: shipping_usd,
        price_usd_total_snapshot: total_usd,
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
    return if admin?
    return if Flipper.enabled?(:shop, current_user)

    redirect_to root_path, alert: "The shop is not available yet."
  end
end
