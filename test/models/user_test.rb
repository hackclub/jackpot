# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with all required attributes" do
    user = User.new(
      hack_club_id: "user_123",
      email: "test@example.com",
      access_token: "token_123",
      role: :user
    )
    assert user.valid?
  end

  test "invalid without hack_club_id" do
    user = User.new(
      email: "test@example.com",
      access_token: "token_123"
    )
    assert_not user.valid?
    assert_includes user.errors[:hack_club_id], "can't be blank"
  end

  test "invalid without email" do
    user = User.new(
      hack_club_id: "user_123",
      access_token: "token_123"
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid without access_token" do
    user = User.new(
      hack_club_id: "user_123",
      email: "test@example.com"
    )
    assert_not user.valid?
    assert_includes user.errors[:access_token], "can't be blank"
  end

  test "hack_club_id must be unique" do
    User.create!(
      hack_club_id: "duplicate_id",
      email: "first@example.com",
      access_token: "token_1",
      role: :user
    )

    user = User.new(
      hack_club_id: "duplicate_id",
      email: "second@example.com",
      access_token: "token_2"
    )
    assert_not user.valid?
    assert_includes user.errors[:hack_club_id], "has already been taken"
  end

  test "default role is nil" do
    user = User.new
    assert_nil user.role
  end

  test "role enum works correctly" do
    user = User.new(
      hack_club_id: "user_123",
      email: "test@example.com",
      access_token: "token_123"
    )

    user.role = :user
    assert_equal "user", user.role
    assert user.role_user?

    user.role = :reviewer
    assert_equal "reviewer", user.role
    assert user.role_reviewer?

    user.role = :admin
    assert_equal "admin", user.role
    assert user.role_admin?
    assert user.full_admin?

    user.role = :super_admin
    assert_equal "super_admin", user.role
    assert user.role_super_admin?
    assert user.full_admin?
  end

  test "from_omniauth creates new user" do
    auth_hash = OmniAuth::AuthHash.new(
      uid: "hack_123",
      provider: "hackclub",
      info: {
        email: "newuser@example.com",
        name: "New User"
      },
      credentials: {
        token: "oauth_token_123"
      }
    )

    user = User.from_omniauth(auth_hash)

    assert user.persisted?
    assert_equal "hack_123", user.hack_club_id
    assert_equal "newuser@example.com", user.email
    assert_equal "New User", user.display_name
    assert_equal "oauth_token_123", user.access_token
    assert_equal "hackclub", user.provider
    assert user.role_user?
  end

  test "from_omniauth updates existing user" do
    existing_user = User.create!(
      hack_club_id: "existing_123",
      email: "old@example.com",
      display_name: "Old Name",
      access_token: "old_token",
      provider: "hackclub",
      role: :user
    )

    auth_hash = OmniAuth::AuthHash.new(
      uid: "existing_123",
      provider: "hackclub",
      info: {
        email: "new@example.com",
        name: "New Name"
      },
      credentials: {
        token: "new_token"
      }
    )

    user = User.from_omniauth(auth_hash)

    assert_equal existing_user.id, user.id
    assert_equal "new@example.com", user.email
    assert_equal "New Name", user.display_name
    assert_equal "new_token", user.access_token
  end

  test "name returns display_name when present" do
    user = User.new(display_name: "John Doe", email: "john@example.com")
    assert_equal "John Doe", user.name
  end

  test "name returns email when display_name is blank" do
    user = User.new(display_name: "", email: "john@example.com")
    assert_equal "john@example.com", user.name
  end

  test "update_access_token! updates token and last_sign_in_at" do
    user = User.create!(
      hack_club_id: "user_123",
      email: "test@example.com",
      access_token: "old_token",
      role: :user
    )

    old_sign_in_time = user.last_sign_in_at
    sleep 1

    user.update_access_token!("new_token")

    assert_equal "new_token", user.access_token
    assert user.last_sign_in_at > old_sign_in_time.to_i
  end
end
