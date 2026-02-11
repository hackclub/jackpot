class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
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
