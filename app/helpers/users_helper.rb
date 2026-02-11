# frozen_string_literal: true

module UsersHelper
  def user_role_badge(user)
    color = case user.role
    when "admin" then "#dc3545"
    else "#6c757d"
    end

    content_tag(:span, user.role.capitalize,
      style: "padding: 0.25rem 0.5rem; background: #{color}; color: white; border-radius: 3px; font-size: 0.875rem;")
  end
end
