# frozen_string_literal: true

module Client
  class Error < StandardError; end
  class Unauthorized < Error; end       # 401
  class Forbidden < Error; end          # 403
  class NotFound < Error; end           # 404
  class Conflict < Error; end           # 409
  class Timeout < Error; end            # networking timeouts
  class ServerError < Error; end        # 500–599
  class BadGateway < ServerError; end   # 502/504 etc.
  class ValidationError < Error; end    # 422
  class ConnectionError < Error; end    # Faraday / Net::HTTP level
  class UnexpectedResponse < Error; end # Fallback when body not JSON or malformed
end
