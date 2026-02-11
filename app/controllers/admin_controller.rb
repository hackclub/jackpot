class AdminController < ApplicationController
  before_action :authenticate_admin!

  def index
  end

  private

  def authenticate_admin!
    redirect_to root_path unless admin?
  end
end
