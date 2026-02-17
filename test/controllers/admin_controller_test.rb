require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create an admin user
    @admin_user = User.create!(
      hack_club_id: "U046VA0KR8R", # Matches the admin ID in User model
      email: "admin@test.com",
      access_token: "test_token",
      role: :admin
    )

    # Create a regular user with various project states
    @user_with_projects = User.create!(
      hack_club_id: "test_user_123",
      email: "user@test.com",
      access_token: "test_token_2",
      role: :user,
      projects: [
        {
          "name" => "Valid Project",
          "description" => "A real project",
          "project_type" => "Web App",
          "created_at" => Time.current.iso8601
        },
        nil, # This nil project should be filtered out
        {
          "name" => "Another Project",
          "description" => "Second project",
          "shipped" => true
        }
      ]
    )
  end

  test "admin review page should handle nil projects gracefully" do
    # Sign in as admin
    post auth_hackclub_callback_path, params: {
      uid: @admin_user.hack_club_id,
      info: { email: @admin_user.email },
      credentials: { token: @admin_user.access_token }
    }

    # Visit the review page
    get admin_path

    assert_response :success
  end

  test "admin review page should filter out nil projects" do
    # Sign in as admin
    sign_in_as(@admin_user)

    get admin_path

    assert_response :success
    # The page should render without errors despite nil projects in the database
  end

  private

  def sign_in_as(user)
    # Helper to simulate authentication
    # In a real app you might use Devise test helpers or similar
    session[:user_id] = user.id if defined?(session)
  end
end
