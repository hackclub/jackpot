class HomeController < ApplicationController
  before_action :authenticate_user!, only: [ :dash ]

  def index
    redirect_to dash_path if user_signed_in?
  end

  def dash
  end
end
