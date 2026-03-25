# frozen_string_literal: true

class AdminShopController < ApplicationController
  before_action :authenticate_admin!

  def index
    @items = ShopItem.includes(shop_grant_type: :shop_category).order(created_at: :desc)
    @shop_purchases_locked = shop_purchases_locked?
    # Only show categories/types that actually have items in them, so the
    # admin UI doesn't list empty groups.
    @categories = ShopCategory
      .joins(shop_grant_types: :shop_items)
      .distinct
      .includes(:shop_grant_types)
      .order(:name)
  end

  def orders
    @shop_purchases_locked = shop_purchases_locked?
    @status_filter = params[:status].presence_in(%w[pending sent refunded all]) || "pending"
    @group_by = params[:group_by].presence_in(%w[flat user item]) || "flat"
    @pending_sort = %w[asc desc].include?(params[:pending_sort].to_s) ? params[:pending_sort] : "desc"

    pending_cards = AdminShop::VirtualOrderCards.pending_cards
    AdminShop::VirtualOrderCards.sort_cards_by_queue_time!(pending_cards, @pending_sort)
    @pending_card_count = pending_cards.size
    @pending_line_count = ShopOrder.pending.count

    if @status_filter == "pending"
      @virtual_cards = pending_cards
      @cards_by_user = AdminShop::VirtualOrderCards.group_cards_by_user(pending_cards)
      @cards_by_item = AdminShop::VirtualOrderCards.group_cards_by_item(pending_cards)
    else
      scope = ShopOrder.includes(:user, :shop_item).order(created_at: :desc)
      scope = scope.where(status: @status_filter) unless @status_filter == "all"
      @history_orders = scope.limit(500)
    end
  end

  def create_item
    item = ShopItem.new(item_params)
    if item.description.blank? && item.price_usd.present?
      dollar_value = item.price_usd.to_f == item.price_usd.to_f.to_i ? item.price_usd.to_i : format("%.2f", item.price_usd)
      item.description = "By purchasing this, you will receive a $#{dollar_value} HCB grant."
    end
    if item.save
      if request.xhr?
        render json: { success: true, item: item.as_json }
      else
        flash[:notice] = "Item created!"
        redirect_to admin_shop_path
      end
    else
      if request.xhr?
        render json: { error: item.errors.full_messages.join(", ") }, status: :unprocessable_entity
      else
        flash[:alert] = item.errors.full_messages.join(", ")
        redirect_to admin_shop_path
      end
    end
  end

  def create_category
    attrs = category_params.to_h.symbolize_keys
    name = attrs[:name].to_s.strip
    key = attrs[:key].to_s.strip
    key = name.parameterize(separator: "_") if key.blank? && name.present?

    category = nil
    if key.present? || name.present?
      category = ShopCategory.where("lower(key) = ? OR lower(name) = ?", key.downcase, name.downcase).first
    end
    category ||= ShopCategory.new

    if category.update(attrs)
      render json: { success: true, category: category.as_json(only: %i[id name key logo_url]) }
    else
      render json: { error: category.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def create_grant_type
    attrs = grant_type_params.to_h.symbolize_keys
    shop_category_id = attrs[:shop_category_id]
    name = attrs[:name].to_s.strip
    key = attrs[:key].to_s.strip
    key = name.parameterize(separator: "_") if key.blank? && name.present?

    grant_type = nil
    if shop_category_id.present? && (key.present? || name.present?)
      grant_type = ShopGrantType
        .where(shop_category_id: shop_category_id)
        .where("lower(key) = ? OR lower(name) = ?", key.downcase, name.downcase)
        .first
    end
    grant_type ||= ShopGrantType.new

    if grant_type.update(attrs)
      render json: {
        success: true,
        grant_type: grant_type.as_json(only: %i[id name key logo_url shop_category_id])
      }
    else
      render json: { error: grant_type.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def update_category
    category = ShopCategory.find(params[:id])
    if category.update(category_params)
      render json: { success: true, category: category.as_json(only: %i[id name key logo_url]) }
    else
      render json: { error: category.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def update_grant_type
    grant_type = ShopGrantType.find(params[:id])
    if grant_type.update(grant_type_params)
      render json: {
        success: true,
        grant_type: grant_type.as_json(only: %i[id name key logo_url shop_category_id])
      }
    else
      render json: { error: grant_type.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def update_item
    item = ShopItem.find(params[:id])
    if item.update(item_params)
      if request.xhr?
        render json: { success: true }
      else
        redirect_to admin_shop_path
      end
    else
      if request.xhr?
        render json: { error: item.errors.full_messages.join(", ") }, status: :unprocessable_entity
      else
        redirect_to admin_shop_path
      end
    end
  end

  def delete_item
    item = ShopItem.find(params[:id])
    item.destroy!
    if request.xhr?
      render json: { success: true }
    else
      redirect_to admin_shop_path
    end
  end

  def update_purchases_lock
    locked = ActiveModel::Type::Boolean.new.cast(params[:locked])
    Rails.cache.write(SHOP_PURCHASES_LOCKED_KEY, locked)
    render json: { success: true, locked: shop_purchases_locked? }
  rescue => e
    Rails.logger.error("Shop purchases lock cache write failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    render json: { error: "Failed to update setting. Please try again." }, status: :internal_server_error
  end

  def reorder_items
    grant_type_id = params[:grant_type_id].presence
    item_ids = params[:item_ids]
    item_ids = Array(item_ids).map(&:to_s).reject(&:blank?) if item_ids.present?

    unless grant_type_id.present? && item_ids.present?
      return render json: { error: "grant_type_id and item_ids required" }, status: :unprocessable_entity
    end

    grant_type = ShopGrantType.find_by(id: grant_type_id)
    unless grant_type
      return render json: { error: "Grant type not found" }, status: :unprocessable_entity
    end

    items = ShopItem.where(shop_grant_type_id: grant_type_id, id: item_ids)
    item_ids.each_with_index do |id, position|
      items.find { |it| it.id.to_s == id.to_s }&.update_column(:position, position)
    end

    render json: { success: true }
  end

  def update_order_status
    order = ShopOrder.find(params[:id])
    new_status = params[:status].to_s
    success = false
    ActiveRecord::Base.transaction do
      success = transition_shop_order_status!(order, new_status)
      raise ActiveRecord::Rollback unless success
    end
    order.reload

    unless success
      return render json: { error: failure_message_for_order_transition(order, new_status) }, status: :unprocessable_entity
    end

    if request.xhr?
      render json: { success: true }
    else
      redirect_back fallback_location: admin_shop_orders_path, notice: "Order updated."
    end
  end

  def bulk_update_order_status
    ids = Array(params[:order_ids]).map(&:to_i).uniq.reject(&:zero?)
    new_status = params[:status].to_s

    if ids.empty?
      return render json: { error: "No orders selected" }, status: :unprocessable_entity
    end

    unless %w[pending sent refunded].include?(new_status)
      return render json: { error: "Invalid status" }, status: :unprocessable_entity
    end

    orders = ShopOrder.where(id: ids).includes(:user).order(:id).to_a
    if orders.size != ids.size
      return render json: { error: "One or more orders were not found" }, status: :not_found
    end

    failed = nil
    ActiveRecord::Base.transaction do
      orders.each do |o|
        next if o.status == new_status

        unless transition_shop_order_status!(o, new_status)
          failed = failure_message_for_order_transition(o, new_status)
          raise ActiveRecord::Rollback
        end
      end
    end

    if failed.present?
      return render json: { error: failed }, status: :unprocessable_entity
    end

    render json: { success: true }
  end

  private

  # Caller must wrap in ActiveRecord::Base.transaction when needed (single or bulk).
  def transition_shop_order_status!(order, new_status)
    return false unless %w[pending sent refunded].include?(new_status)
    return true if order.status == new_status

    order.lock!
    order.user.reload.lock!

    if new_status == "refunded" && order.status != "refunded"
      order.user.update!(chip_am: order.user.chip_am.to_f + order.price.to_f)
    end

    if order.status == "refunded" && new_status != "refunded"
      return false if order.user.chip_am.to_f < order.price.to_f

      order.user.update!(chip_am: order.user.chip_am.to_f - order.price.to_f)
    end

    order.update!(status: new_status)
    order.reload.status == new_status
  end

  def failure_message_for_order_transition(order, new_status)
    return "Invalid status" unless %w[pending sent refunded].include?(new_status)

    order.reload
    if order.status == "refunded" && new_status != "refunded"
      return "User doesn't have enough chips to un-refund."
    end

    "Could not update order."
  end

  def item_params
    source = params[:admin_shop].presence || params
    source.permit(:name, :price, :price_usd, :dollar_per_hour, :item_link, :image_url, :description, :active, :shop_grant_type_id, :max_per_person)
  end

  def category_params
    source = params[:admin_shop].presence || params
    source.permit(:name, :key, :logo_url)
  end

  def grant_type_params
    source = params[:admin_shop].presence || params
    source.permit(:shop_category_id, :name, :key, :logo_url)
  end

  def authenticate_admin!
    unless admin?
      redirect_to root_path, alert: "Access denied. Admin only."
    end
  end
end
