class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :user_signed_in?, :admin?

  before_action :check_access_flipper
  before_action :initialize_request_counters

  private

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

  def admin?
    return false unless user_signed_in?

    # Localhost convenience: treat any signed-in user as admin when running
    # locally in development. This does not affect production.
    return true if Rails.env.development? && request.local?

    current_user.role_admin?
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
