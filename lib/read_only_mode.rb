# frozen_string_literal: true

class ReadOnlyMode
  SAFE_METHODS = %w[GET HEAD OPTIONS].freeze
  MESSAGE = "Jackpot is now read-only. Submissions, uploads, purchases, and sign-ins are closed."

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless Rails.application.config.x.read_only

    request = ActionDispatch::Request.new(env)
    blocked?(request) ? reject(request) : @app.call(env)
  end

  private

  def blocked?(request)
    return true if sign_in_path?(request.path)
    return false if SAFE_METHODS.include?(request.request_method)

    !(request.path == "/signout" && request.delete?)
  end

  def sign_in_path?(path)
    path.start_with?("/auth/") && path != "/auth/hackclub"
  end

  def reject(request)
    if request.get_header("HTTP_ACCEPT").to_s.include?("text/html")
      body = <<~HTML
        <!doctype html>
        <html lang="en">
          <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Jackpot is read-only</title></head>
          <body style="font-family: Georgia, serif; background: #111; color: #f5f5f5; display: grid; place-items: center; min-height: 100vh; margin: 0; padding: 16px; text-align: center;">
            <main>
              <h1>Jackpot is read-only</h1>
              <p>#{ERB::Util.html_escape(MESSAGE)}</p>
              <p><a href="/" style="color: #d4a017;">Back to Jackpot</a></p>
            </main>
          </body>
        </html>
      HTML
      [ 403, { "content-type" => "text/html; charset=utf-8" }, [ body ] ]
    else
      [ 403, { "content-type" => "application/json; charset=utf-8" }, [ { error: MESSAGE }.to_json ] ]
    end
  end
end
