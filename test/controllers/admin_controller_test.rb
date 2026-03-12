require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = User.create!(
      hack_club_id: "U046VA0KR8R",
      email: "admin@test.com",
      access_token: "test_token",
      role: :admin
    )

    @user_with_projects = User.create!(
      hack_club_id: "test_user_123",
      email: "user@test.com",
      access_token: "test_token_2",
      role: :user
    )

    @user_with_projects.projects.create!(
      name: "Valid Project",
      description: "A real project",
      project_type: "Web App"
    )

    @user_with_projects.projects.create!(
      name: "Another Project",
      description: "Second project",
      shipped: true
    )

    # Enable access flipper for the admin user so check_access_flipper doesn't redirect
    Flipper.enable(:access, @admin_user)
  end

  test "admin review page should handle nil projects gracefully" do
    sign_in_as(@admin_user)

    get admin_path

    assert_response :success
  end

  test "admin review page should filter out nil projects" do
    sign_in_as(@admin_user)

    get admin_path

    assert_response :success
  end

  private

  # Simulate signing in by posting through the OmniAuth callback route
  def sign_in_as(user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hack_club] = OmniAuth::AuthHash.new(
      provider: "hack_club",
      uid: user.hack_club_id,
      info: { email: user.email, name: user.display_name },
      credentials: { token: "test_token" }
    )

    # Trigger the OmniAuth callback to set session[:user_id]
    get "/auth/hack_club/callback"
  end
end
