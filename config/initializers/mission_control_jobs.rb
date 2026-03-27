# frozen_string_literal: true

# Configure Mission Control Jobs to require admin access
Rails.application.config.after_initialize do
  MissionControl::Jobs::ApplicationController.class_eval do
    before_action :require_admin!

    private

    def require_admin!
      unless current_user&.full_admin?
        redirect_to "/", alert: "You are not authorized to access this page."
      end
    end
  end
end
