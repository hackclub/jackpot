# frozen_string_literal: true

class AdminShopController < ApplicationController
  before_action :authenticate_admin!

  def index
    @items = ShopItem.includes(shop_grant_type: :shop_category).order(created_at: :desc)
    @orders = ShopOrder.includes(:user, :shop_item).order(created_at: :desc).limit(100)
    @categories = ShopCategory.includes(:shop_grant_types).order(:name)
  end

  def create_item
    item = ShopItem.new(item_params)
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
    category = ShopCategory.new(category_params)
    if category.save
      render json: { success: true, category: category.as_json(only: %i[id name key logo_url]) }
    else
      render json: { error: category.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def create_grant_type
    grant_type = ShopGrantType.new(grant_type_params)
    if grant_type.save
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

  def update_order_status
    order = ShopOrder.find(params[:id])
    new_status = params[:status]

    unless %w[pending sent refunded].include?(new_status)
      return render json: { error: "Invalid status" }, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      order.lock!
      order.user.reload.lock!

      # If refunding, give chips back
      if new_status == "refunded" && order.status != "refunded"
        order.user.update!(chip_am: order.user.chip_am.to_f + order.price.to_f)
      end

      # If un-refunding (changing from refunded to something else), deduct chips again
      if order.status == "refunded" && new_status != "refunded"
        if order.user.chip_am.to_f < order.price.to_f
          raise ActiveRecord::Rollback
        end
        order.user.update!(chip_am: order.user.chip_am.to_f - order.price.to_f)
      end

      order.update!(status: new_status)
    end

    unless order.status == new_status
      return render json: { error: "User doesn't have enough chips to un-refund." }, status: :unprocessable_entity
    end

    if request.xhr?
      render json: { success: true }
    else
      redirect_to admin_shop_path
    end
  end

  private

  def item_params
    source = params[:admin_shop].presence || params
    source.permit(:name, :price, :item_link, :image_url, :description, :active, :shop_grant_type_id)
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
