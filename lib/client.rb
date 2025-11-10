# frozen_string_literal: true

require_relative "client/version"
require_relative "client/config"
require_relative "client/errors"
require_relative "client/hmac"
require_relative "client/http"

module Client
  @clients = {} # registry of named client configs

  class << self
    # For backward compatibility (single-client mode)
    def config
      @clients[:default] ||= Client::Config.new
    end

    # Configure a specific client (or default)
    def configure(name = :default)
      @clients[name.to_sym] ||= Client::Config.new
      yield(@clients[name.to_sym])
    end

    # Retrieve configuration for a named client
    def [](name = :default)
      @clients[name.to_sym] || raise("No client configured for #{name.inspect}")
    end

    # Return all configured clients
    def all
      @clients
    end

    # --- Client API (bound to a specific config) ---

    def execute(client_name = :default, operation:, caller_id:, params: {}, async: false, idem_key: nil, timeouts: nil)
      http(client_name).execute(
        operation: operation,
        caller_id: caller_id,
        params: params,
        async: async,
        idem_key: idem_key,
        timeouts: timeouts
      )
    end

    def fetch_tasks(client_name = :default, caller_id:)
      http(client_name).fetch_tasks(caller_id: caller_id)
    end

    def fetch_task(client_name = :default, task_name:, caller_id:)
      http(client_name).fetch_task(task_name: task_name, caller_id: caller_id)
    end

    def wait(client_name = :default, idem_key:, caller_id:)
      http(client_name).wait(idem_key: idem_key, caller_id: caller_id)
    end

    private

    def http(client_name)
      cfg = @clients[client_name.to_sym] || raise("Client not configured: #{client_name.inspect}")
      Client::HTTP.new(config: cfg)
    end
  end
end
