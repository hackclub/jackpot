# frozen_string_literal: true

class ReviewerController < ApplicationController
  skip_before_action :check_access_flipper
  before_action :authenticate_reviewer_portal!

  def index
    redirect_to admin_path if current_user.full_admin?
  end

  private

  def authenticate_reviewer_portal!
    unless user_signed_in?
      redirect_to "/auth/hackclub", alert: "Please sign in."
      return
    end
    unless current_user.review_privileged?
      redirect_to root_path, alert: "Access denied."
    end
  end
end
