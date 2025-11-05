# frozen_string_literal: true

require 'openssl'

module Client
  module HMAC
    module_function

    # Returns a hash of headers for signing a request body.
    # Example usage:
    #   Client::HMAC.sign(caller: 'billing', secret: 'xyz', body: '{"op":"echo"}')
    #
    # → {
    #     'X-Orch-Timestamp' => '1730658000',
    #     'X-Orch-Caller'    => 'billing',
    #     'X-Orch-Signature' => 'deadbeef...'
    #   }
    def sign(caller:, secret:, body:)
      ts = Time.now.to_i.to_s
      payload = ts + '.' + body.to_s
      sig = OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
      {
        'X-Orch-Timestamp' => ts,
        'X-Orch-Caller'    => caller.to_s,
        'X-Orch-Signature' => sig
      }
    end

    # Verifies that a request's signature matches what we would generate.
    # Used mainly in tests or debugging; not needed for normal clients.
    def verify?(caller:, secret:, body:, headers:, skew: 300)
      ts = headers['X-Orch-Timestamp'].to_i
      now = Time.now.to_i
      return false if (ts - now).abs > skew

      expected = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{ts}.#{body}")
      expected == headers['X-Orch-Signature']
    end
  end
end
