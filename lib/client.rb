# frozen_string_literal: true

require_relative 'client/version'
require_relative 'client/config'
require_relative 'client/errors'
require_relative 'client/hmac'
require_relative 'client/http'

module Client
  class << self
    def config
      @config ||= Client::Config.new
    end

    def configure
      yield(config)
    end

    # POST /executions
    def execute(operation:, caller_id:, params: {}, async: false, idem_key: nil, timeouts: nil)
      Client::HTTP.new(config: config).execute(
        operation: operation,
        caller_id: caller_id,
        params: params,
        async: async,
        idem_key: idem_key,
        timeouts: timeouts
      )
    end

    # GET /executions/fetch_tasks
    def fetch_tasks(caller_id:)
      Client::HTTP.new(config: config).fetch_tasks(
        caller_id: caller_id
      )
    end

    # GET /executions/fetch_task?task=<task_name>
    def fetch_task(task_name:, caller_id:)
      Client::HTTP.new(config: config).fetch_task(
        task_name: task_name,
        caller_id: caller_id
      )
    end

    # GET /executions/wait/:idem_key
    def wait(idem_key:, caller_id:)
      Client::HTTP.new(config: config).wait(
        idem_key: idem_key,
        caller_id: caller_id
      )
    end
  end
end
