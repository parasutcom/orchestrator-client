# frozen_string_literal: true

require 'rspec'
require 'json'
require_relative '../lib/client'

RSpec.describe Client do
  before do
    Client.configure do |c|
      c.host_base   = 'http://example.com/executions'
      c.hmac_secret = 'secret'
      c.timeouts    = { open: 1, read: 1, write: 1 }
      c.logger      = nil
    end
  end

  it 'has a version number' do
    expect(Client::VERSION).not_to be_nil
  end

  it 'yields config when configured' do
    expect do |blk|
      Client.configure(&blk)
    end.to yield_with_args(Client::Config)
  end

  it 'allows reading config after configure' do
    expect(Client.config.host_base).to eq('http://example.com/executions')
  end

  it 'delegates execute to Client::HTTP' do
    dummy = double('http')
    expect(Client::HTTP).to receive(:new).and_return(dummy)
    expect(dummy).to receive(:execute).with(
      operation: 'echo',
      caller_id: 'billing',
      params: { msg: 'hi' },
      async: false,
      idem_key: nil,
      timeouts: nil
    ).and_return('echoed' => 'hi')

    result = Client.execute(operation: 'echo', caller_id: 'billing', params: { msg: 'hi' })
    expect(result).to eq('echoed' => 'hi')
  end

  it 'computes valid HMAC headers' do
    body = { foo: 'bar' }.to_json
    headers = Client::HMAC.sign(caller: 'svc', secret: 'secret', body: body)

    expect(headers).to include('X-Orch-Timestamp', 'X-Orch-Caller', 'X-Orch-Signature')
    expect(headers['X-Orch-Caller']).to eq('svc')
    expect(headers['X-Orch-Signature'].length).to eq(64) # SHA256 hex
  end
end
