# frozen_string_literal: true

# Thread-safe request counter for calculating requests/sec over a rolling 60s window
module RequestCounter
  @mutex = Mutex.new
  @requests = []

  # Records a request timestamp
  def self.record!
    @mutex.synchronize do
      now = Time.current
      @requests << now
      # Only keep the last 60 seconds of requests
      @requests.reject! { |t| t < now - 60 }
    end
  end

  # Returns requests per second over the last 60 seconds
  def self.requests_per_second
    @mutex.synchronize do
      now = Time.current
      @requests.reject! { |t| t < now - 60 }
      return 0.0 if @requests.empty?

      (@requests.size / 60.0).round(1)
    end
  end
end
