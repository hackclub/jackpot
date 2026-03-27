# frozen_string_literal: true

class AdminConstraint
  def self.matches?(request)
    u = User.find_by(id: request.session[:user_id])
    u.present? && u.full_admin?
  end
end
