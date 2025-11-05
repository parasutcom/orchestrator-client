# frozen_string_literal: true

module Client
  class Config
    attr_accessor :host_base,
                  :hmac_secret,
                  :hmac_skew,
                  :timeouts,
                  :logger,
                  :poll_interval,
                  :max_wait_time

    def initialize
      @host_base     = ENV['ORCH_AGENT_HOST'] || 'http://localhost:4002/executions'
      @hmac_secret   = ENV['HMAC_SECRET'] || 'supersecret'
      @hmac_skew     = 300
      @timeouts      = { open: 2.0, read: 3.0, write: 3.0 }
      @poll_interval = 1.0
      @max_wait_time = 30.0
      @logger        = defined?(Logger) ? Logger.new($stdout) : nil
    end
  end
end
