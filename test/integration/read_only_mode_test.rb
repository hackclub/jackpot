require "test_helper"

class ReadOnlyModeTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(hack_club_id: "U_READ_ONLY", email: "ro@test.com", access_token: "tok", role: :user)
    @admin = User.create!(hack_club_id: "U_READ_ONLY_ADMIN", email: "ro-admin@test.com", access_token: "tok", role: :admin)
    @project = @user.projects.create!(name: "Frozen", hackatime_hours: 3.5)
    Flipper.enable(:access)
  end

  teardown do
    Rails.application.config.x.read_only = false
  end

  test "sign-in routes are closed" do
    enable_read_only!

    post "/auth/hack_club", headers: { "Accept" => "text/html" }
    assert_response :forbidden
    assert_includes response.body, "read-only"

    get "/auth/hack_club/callback"
    assert_response :forbidden
    assert_nil session[:user_id]
  end

  test "anonymous writes are rejected before reaching the app" do
    enable_read_only!

    assert_no_difference -> { RsvpTable.count } do
      post "/rsvps", params: { emails: [ "a@b.com" ] }, as: :json
    end
    assert_response :forbidden
    assert_equal ReadOnlyMode::MESSAGE, response.parsed_body["error"]
  end

  test "signed-in users can read but not write" do
    sign_in_as(@user)
    enable_read_only!

    get deck_path
    assert_response :success
    assert_in_delta 3.5, @project.reload.hackatime_hours.to_f

    get status_path
    assert_response :success

    assert_no_difference -> { Project.count } do
      post save_project_path, params: { project_name: "New" }, xhr: true
    end
    assert_response :forbidden

    post ship_project_path, params: { project_index: 0 }, xhr: true
    assert_response :forbidden
    assert_not @project.reload.shipped?

    post upload_journal_image_path, xhr: true
    assert_response :forbidden

    delete delete_project_path, params: { project_index: 0 }, xhr: true
    assert_response :forbidden
    assert Project.exists?(@project.id)
  end

  test "admins can read but not write" do
    sign_in_as(@admin)
    enable_read_only!

    get admin_path
    assert_response :success

    patch admin_user_chip_am_path(@user), params: { chip_am: 1000, note: "nope" }
    assert_response :forbidden
  end

  test "signing out still works" do
    sign_in_as(@user)
    enable_read_only!

    delete signout_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "the admin Ruby console is gone" do
    sign_in_as(@admin)

    get "/admin/console"
    assert_response :not_found
  end

  private

  def enable_read_only!
    Rails.application.config.x.read_only = true
  end

  def sign_in_as(user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hack_club] = OmniAuth::AuthHash.new(
      provider: "hack_club",
      uid: user.hack_club_id,
      info: { email: user.email, name: user.display_name },
      credentials: { token: "test_token" }
    )
    get "/auth/hack_club/callback"
  end
end
