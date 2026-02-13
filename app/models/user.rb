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
      profile_photo_url: auth.info.image || auth.extra.raw_info.profile.image_192
    )
    user.role ||= :user
    if user.new_record?
      user.save!
      UserAirtableSyncJob.perform_later(user.id)
    else
      user.save!
    end
    user
  end

  def update_access_token!(token)
    update!(access_token: token, last_sign_in_at: Time.current)
  end

  def name
    display_name.presence || email
  end
end
