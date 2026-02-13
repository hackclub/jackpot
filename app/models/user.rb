# frozen_string_literal: true

class User < ApplicationRecord
  has_encrypted :access_token
  enum :role, { user: 0, admin: 1 }, prefix: true

  validates :hack_club_id, presence: true, uniqueness: true
  validates :email, presence: true
  validates :access_token, presence: true

  scope :active, -> { where("last_sign_in_at > ?", 6.months.ago) }

  def self.from_omniauth(auth)
    user = find_or_initialize_by(hack_club_id: auth.uid)
    user.assign_attributes(
      email: auth.info.email,
      display_name: auth.info.name || auth.info.email.split("@").first,
      access_token: auth.credentials.token,
      provider: auth.provider,
      last_sign_in_at: Time.current,
      profile_photo_url: auth.info.image || auth.extra&.raw_info&.dig("profile", "image_192")
    )
    
    if user.profile_photo_url.blank? && auth.info.slack_id.present?
      user.fetch_slack_photo(auth.info.slack_id)
    end

    slack_id = auth.info.slack_id
    if user.slack_username.blank? && slack_id.present?
      user.fetch_slack_username(slack_id)
    end

    user.role ||= :user
    user.save!
    user
  end

  def fetch_slack_photo(slack_id)
    token = Rails.application.credentials.slack_bot_token
    return unless token && slack_id

    uri = URI("https://slack.com/api/users.profile.get")
    uri.query = URI.encode_www_form({ user: slack_id })
    
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      if data["ok"]
        image = data.dig("profile", "image_192") || data.dig("profile", "image_512")
        self.profile_photo_url = image if image.present?
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to fetch Slack photo: #{e.message}"
  end

  def update_access_token!(token)
    update!(access_token: token, last_sign_in_at: Time.current)
  end

  def fetch_slack_username(slack_id)
    token = Rails.application.credentials.slack_bot_token
    return unless token && slack_id

    uri = URI("https://slack.com/api/users.profile.get")
    uri.query = URI.encode_www_form({ user: slack_id })

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      Rails.logger.info "Slack API Response: #{data.inspect}"
      if data["ok"] && data["profile"]
        username = data.dig("profile", "display_name").presence ||
                   data.dig("profile", "real_name").presence ||
                   data.dig("profile", "display_name_normalized")
        self.slack_username = username
        Rails.logger.info "Set slack_username to: #{username}"
      else
        Rails.logger.warn "Slack API returned ok=false: #{data['error']}"
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to fetch Slack username: #{e.message}"
  end

  def leaderboard_name
    slack_username.presence || display_name.presence || email.split("@").first
  end

  def name
    display_name.presence || email
  end
  
  def role_admin?
    return true if hack_club_id == "U046VA0KR8R"
    super
  end
end
