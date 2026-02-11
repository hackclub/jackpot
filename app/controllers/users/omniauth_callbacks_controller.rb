# frozen_string_literal: true

class Users::OmniauthCallbacksController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def hack_club
    auth = request.env["omniauth.auth"]
    @user = User.from_omniauth(auth)

    if @user.persisted?
      session[:user_id] = @user.id
      flash[:notice] = "Signed in successfully!"
      redirect_to after_sign_in_path
    else
      flash[:alert] = "Authentication failed. Please try again."
      redirect_to root_path
    end
  end

  def failure
    flash[:alert] = "Authentication failed: #{failure_message}"
    redirect_to root_path
  end

  private

  def after_sign_in_path
    session[:user_return_to] || root_path
  end

  def failure_message
    request.env["omniauth.error"]&.[](:message) || "Unknown error"
  end
end
