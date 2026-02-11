# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :hack_club,
           ENV.fetch("HACK_CLUB_CLIENT_ID", nil),
           ENV.fetch("HACK_CLUB_CLIENT_SECRET", nil),
           scope: "email profile",
           callback_path: "/auth/hack_club/callback"
end

OmniAuth.config.logger = Rails.logger

OmniAuth.config.on_failure = proc do |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
end
