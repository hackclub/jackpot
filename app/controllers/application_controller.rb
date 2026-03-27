class ApplicationController < ActionController::Base
  SHOP_PURCHASES_LOCKED_KEY = "shop_purchases_locked"

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :user_signed_in?, :admin?, :review_privileged?, :full_admin?

  before_action :check_access_flipper
  before_action :initialize_request_counters

  private

  def shop_purchases_locked?
    value = Rails.cache.read(SHOP_PURCHASES_LOCKED_KEY)
    ActiveModel::Type::Boolean.new.cast(value)
  rescue => e
    Rails.logger.warn("Shop purchases lock cache read failed: #{e.message}")
    false
  end

  def check_access_flipper
    if user_signed_in? && !Flipper.enabled?(:access, current_user)
      session[:user_id] = nil
      redirect_to root_path, alert: "Access denied. Please contact an administrator."
    end
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
  end

  # Shop, admin index, console, Blazer, etc. (admin + super_admin roles).
  def admin?
    full_admin?
  end

  # Project review queue, stats, deck approve/reject, commenting as staff.
  def review_privileged?
    return false unless user_signed_in?

    return true if localhost_staff_bypass?

    current_user.review_privileged?
  end

  def full_admin?
    return false unless user_signed_in?

    return true if localhost_staff_bypass?

    current_user.full_admin?
  end

  # Optional dev-only shortcut: set JACKPOT_LOCALHOST_STAFF_BYPASS=true in .env so any signed-in user
  # on localhost is treated as full admin + reviewer (matches old behavior). By default this is off
  # so local testing uses real DB roles without relying on .env loading order.
  def localhost_staff_bypass?
    return false unless Rails.env.development? && request.local?

    ActiveModel::Type::Boolean.new.cast(ENV["JACKPOT_LOCALHOST_STAFF_BYPASS"])
  end

  def authenticate_user!
    return if user_signed_in?

    store_location
    redirect_to "/auth/hackclub", alert: "Please sign in to continue."
  end

  def store_location
    session[:user_return_to] = request.fullpath
  end

  def after_sign_in_path
    path = session.delete(:user_return_to)
    path.present? && path.start_with?("/") && !path.start_with?("//") ? path : root_path
  end

  # Resets all per-request counters in thread-local storage
  def initialize_request_counters
    Thread.current[:cache_hits] = 0
    Thread.current[:cache_misses] = 0
    Thread.current[:db_query_count] = 0
    Thread.current[:db_cached_count] = 0
    RequestCounter.record!
  end
end
