# frozen_string_literal: true

class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    user = User.from_omniauth(auth)

    if user.persisted?
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
