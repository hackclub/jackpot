# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :hack_club,
           Rails.application.config.x.hack_club.client_id,
           Rails.application.config.x.hack_club.client_secret,
           scope: "email profile slack_id address basic_info",
           callback_path: "/auth/hack_club/callback"
end

OmniAuth.config.logger = Rails.logger

OmniAuth.config.on_failure = proc do |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
end
