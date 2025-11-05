# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative 'hmac'
require_relative 'errors'

module Client
  class HTTP
    def initialize(config:)
      @config = config
      @logger = config.logger
    end

    # Performs the main execution request to the Agent.
    # - async: false → POST /executions
    # - async: true  → POST /executions?async=1
    def execute(operation:, caller_id:, params:, async:, idem_key:, timeouts: nil)
      uri = URI.join(normalized_base, 'executions')
      uri.query = 'async=1' if async

      body = JSON.dump(
        operation: operation,
        caller: caller_id,
        params: params,
        idem_key: idem_key
      )

      headers = Client::HMAC.sign(
        caller: caller_id,
        secret: @config.hmac_secret,
        body: body
      )

      res = request(:post, uri, body, headers, timeouts)
      case res.code.to_i
      when 200
        JSON.parse(res.body)
      when 202
        JSON.parse(res.body)
      when 401
        raise Client::Unauthorized, parse_message(res)
      when 403
        raise Client::Forbidden, parse_message(res)
      when 404
        raise Client::NotFound, parse_message(res)
      when 409
        raise Client::Conflict, parse_message(res)
      when 422
        raise Client::ValidationError, parse_message(res)
      when 500..599
        raise Client::ServerError, parse_message(res)
      else
        raise Client::UnexpectedResponse, "HTTP #{res.code}: #{res.body}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Client::Timeout, 'request timed out'
    rescue Errno::ECONNREFUSED, SocketError => e
      raise Client::ConnectionError, e.message
    end

    # Polls /executions/status/:idem_key until result is ready or timeout
    def wait(idem_key:, caller_id:)
      raise ArgumentError, 'idem_key required' if idem_key.to_s.strip.empty?
    
      uri = URI.join(normalized_base, "executions/wait/#{idem_key}")
    
      headers = Client::HMAC.sign(
        caller: caller_id,
        secret: @config.hmac_secret,
        body: ''
      )
    
      res = request(:get, uri, nil, headers, nil)
      code = res.code.to_i
    
      case code
      when 200, 202
        JSON.parse(res.body, symbolize_names: true)
      when 401
        raise Client::Unauthorized, parse_message(res)
      else
        raise Client::UnexpectedResponse, "HTTP #{code}: #{res.body}"
      end
    rescue StandardError => e
      @logger.error("[client] wait error: #{e.class} - #{e.message}")
      nil
    end

    def fetch_tasks(caller_id:)
      uri = URI.join(normalized_base, 'executions/fetch_tasks')
    
      headers = Client::HMAC.sign(
        caller: caller_id,
        secret: @config.hmac_secret,
        body: ''
      )
    
      res = request(:get, uri, nil, headers, nil)
      code = res.code.to_i
    
      case code
      when 200
        body = JSON.parse(res.body)
        Array(body['tasks']).map { |t| deep_symbolize_keys(t) }
      when 401
        raise Client::Unauthorized, parse_message(res)
      when 403
        raise Client::Forbidden, parse_message(res)
      else
        raise Client::UnexpectedResponse, "HTTP #{code}: #{res.body}"
      end
    rescue StandardError => e
      @logger.error("[client] fetch_tasks error: #{e.class} - #{e.message}")
      []
    end

    def fetch_task(task_name:, caller_id:)
      raise ArgumentError, 'task_name required' if task_name.to_s.strip.empty?
    
      uri = URI.join(normalized_base, 'executions/fetch_task')
      uri.query = URI.encode_www_form(task: task_name)
    
      headers = Client::HMAC.sign(
        caller: caller_id,
        secret: @config.hmac_secret,
        body: ''
      )
    
      res = request(:get, uri, nil, headers, nil)
      code = res.code.to_i
    
      case code
      when 200
        JSON.parse(res.body, symbolize_names: true)
      when 404
        raise Client::NotFound, parse_message(res)
      when 401
        raise Client::Unauthorized, parse_message(res)
      else
        raise Client::UnexpectedResponse, "HTTP #{code}: #{res.body}"
      end
    rescue StandardError => e
      @logger.error("[client] fetch_task error: #{e.class} - #{e.message}")
      nil
    end

    private

    def deep_symbolize_keys(obj)
      case obj
      when Array
        obj.map { |v| deep_symbolize_keys(v) }
      when Hash
        obj.each_with_object({}) do |(k, v), memo|
          memo[k.to_sym] = deep_symbolize_keys(v)
        end
      else
        obj
      end
    end

    def request(method, uri, body, headers, timeouts)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

      opts = timeouts || @config.timeouts
      http.open_timeout  = opts[:open]
      http.read_timeout  = opts[:read]
      http.write_timeout = opts[:write] if http.respond_to?(:write_timeout)

      req = case method
            when :post
              Net::HTTP::Post.new(uri.request_uri)
            when :get
              Net::HTTP::Get.new(uri.request_uri)
            else
              raise ArgumentError, "unsupported method #{method}"
            end

      headers.each { |k, v| req[k] = v }
      req['Content-Type'] = 'application/json' if body
      req.body = body if body

      @logger.info("[client] #{method.upcase} #{uri}")
      http.request(req)
    end

    def parse_message(res)
      json = JSON.parse(res.body) rescue nil
      json && json['message'] ? json['message'] : res.body
    end

    def normalized_base
      @config.host_base.end_with?('/') ? @config.host_base : "#{@config.host_base}/"
    end
  end
end
