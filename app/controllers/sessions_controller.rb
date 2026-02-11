# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :check_access_flipper
  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)

    if user.persisted?
      # Check if user has access flipper enabled
      unless Flipper.enabled?(:access, user)
        flash[:alert] = "We are not open yet wait!."
        redirect_to root_path
        return
      end

      session[:user_id] = user.id
      flash[:notice] = "Signed in successfully!"
      redirect_to after_sign_in_path
    else
      flash[:alert] = "Authentication failed. Please try again."
      redirect_to root_path
    end
  end

  def destroy
    session[:user_id] = nil
    flash[:notice] = "Signed out successfully!"
    redirect_to root_path
  end

  def failure
    flash[:alert] = "Authentication failed: #{params[:message]}"
    redirect_to root_path
  end

  private

  def after_sign_in_path
    session[:user_return_to] || root_path
  end
end
