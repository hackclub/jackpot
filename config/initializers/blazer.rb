# frozen_string_literal: true

# Configure Blazer to require admin access
Rails.application.config.after_initialize do
  Blazer::BaseController.class_eval do
    def require_admin
      unless current_user&.full_admin?
        redirect_to "/", alert: "You are not authorized to access this page."
      end
    end
  end
end
