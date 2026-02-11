# frozen_string_literal: true

class AdminConstraint
  def self.matches?(request)
    request.session[:user_id].present? && User.find_by(id: request.session[:user_id])&.role_admin?
  end
end
