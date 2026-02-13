class HomeController < ApplicationController
  def index
    redirect_to deck_path if user_signed_in?
  end
end
