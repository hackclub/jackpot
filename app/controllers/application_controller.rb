class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :user_signed_in?, :admin?

  before_action :check_access_flipper

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
    user_signed_in? && current_user.role_admin?
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
    session.delete(:user_return_to) || root_path
  end
end
