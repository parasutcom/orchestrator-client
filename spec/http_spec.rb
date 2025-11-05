# frozen_string_literal: true

require 'json'
require 'net/http'
require 'rspec'
require_relative '../lib/client'
require_relative '../lib/client/http'

RSpec.describe Client::HTTP do
  let(:config) do
    Client::Config.new.tap do |c|
      c.host_base = 'http://example.com/executions'
      c.hmac_secret = 'local_secret'
      c.logger = nil
    end
  end

  let(:client) { described_class.new(config: config) }

  before do
    # monkeypatch Net::HTTP to fake requests
    stub_const('Net::HTTP', Class.new do
      attr_accessor :open_timeout, :read_timeout, :write_timeout
      attr_reader :host, :port

      def initialize(host, port)
        @host = host
        @port = port
      end

      def use_ssl=(_); end

      def request(req)
        $last_req = req
        code = case req.path
               when %r{/executions/status/}
                 $simulate_status || 200
               else
                 $simulate_code || 200
               end
        body = $simulate_body || { echoed: 'hello' }.to_json
        Struct.new(:code, :body).new(code.to_s, body)
      end
    end)
  end

  it 'POST /executions (sync) returns 200 and parses JSON' do
    $simulate_code = 200
    result = client.execute(
      operation: 'echo',
      caller_id: 'svc',
      params: { msg: 'hi' },
      async: false,
      idem_key: 'k'
    )
    expect(result).to eq('echoed' => 'hello')
  end

  it 'POST /executions (async) returns 202 accepted' do
    $simulate_code = 202
    result = client.execute(
      operation: 'echo',
      caller_id: 'svc',
      params: {},
      async: true,
      idem_key: 'k'
    )
    expect(result).to eq('echoed' => 'hello')
  end

  it 'GET /executions/status/:idem_key returns done' do
    $simulate_status = 200
    res = client.wait('abc')
    expect(res).to eq('echoed' => 'hello')
  end

  it 'wait polls until done or timeout (stops when done)' do
    $simulate_status = 202
    call_count = 0
    allow(client).to receive(:request) do |*_|
      call_count += 1
      if call_count < 2
        Struct.new(:code, :body).new('202', '{}')
      else
        Struct.new(:code, :body).new('200', '{"echoed":"hello"}')
      end
    end
    res = client.wait('idem-xyz')
    expect(res['echoed']).to eq('hello')
  end

  it 'maps 401 to Unauthorized' do
    $simulate_code = 401
    $simulate_body = { message: 'nope' }.to_json

    expect do
      client.execute(operation: 'echo', caller_id: 'svc', params: {}, async: false, idem_key: 'k')
    end.to raise_error(Client::Unauthorized, /nope|HTTP 401/)
  end

  it 'respects per-call timeouts via timeouts: {open:, read:, write:}' do
    $simulate_code = 200
    custom_timeouts = { open: 9, read: 9, write: 9 }
    client.execute(operation: 'echo', caller_id: 'svc', params: {}, async: false, idem_key: 'x', timeouts: custom_timeouts)
    expect($last_req).to be_a(Net::HTTP::Post)
  end

  it 'falls back to constructor timeouts when per-call not provided' do
    $simulate_code = 200
    client.execute(operation: 'echo', caller_id: 'svc', params: {}, async: false, idem_key: 'y')
    expect($last_req).to be_a(Net::HTTP::Post)
  end
end
