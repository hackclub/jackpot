# frozen_string_literal: true

class StatusController < ApplicationController
  before_action :authenticate_user!
  before_action :require_status_feature

  def index
  end

  private

  def require_status_feature
    return if Flipper.enabled?(:status, current_user)

    redirect_to root_path, alert: "The status page is not available yet."
  end
end
