require 'spec_helper'
require 'faraday'

RSpec.describe Flagsmith::RealtimeClient do
  let(:mock_logger) { double('Logger', warn: nil, info: nil, error: nil) }
  let(:mock_config) do
    double('Config',
           realtime_api_url: 'https://example.com/',
           environment_key: 'test-environment',
           logger: mock_logger)
  end
  let(:mock_environment) { double('Environment',
                           api_key: 'some_api_key' )}
  let(:mock_main) { double('Main',
                           update_environment: nil,
                           environment: mock_environment,
                          ) }
  let(:realtime_client) { described_class.new(mock_config) }
  let(:sse_response) do
    <<~SSE
      data: {"updated_at": 1}

      data: {"updated_at": 2}
    SSE
  end
  let(:retry_interval) { 0.01 }

  # Minimal stand-in for a Faraday connection that streams the response the
  # way the real adapter does: chunks are handed to `on_data` while the request
  # is still open, and the response is only returned once the server hangs up.
  let(:stream_chunks) { [sse_response] }
  let(:connection_count) { [0] }
  let(:updates_seen_while_connected) { [] }
  let(:update_count) { [0] }
  let(:mock_connection) do
    connection = double('Faraday::Connection')
    allow(connection).to receive(:get) do |&block|
      connection_count[0] += 1
      request = Faraday::Request.create(:get) { |req| req.options = Faraday::RequestOptions.new }
      block&.call(request)
      stream_chunks.each { |chunk| request.options.on_data&.call(chunk, chunk.bytesize, nil) }
      updates_seen_while_connected << update_count[0]
      double('Response', body: '')
    end
    connection
  end

  before(:each) do
    allow(Faraday).to receive(:new).and_return(mock_connection)
    allow(mock_main).to receive(:update_environment) { update_count[0] += 1 }
    allow(Thread).to receive(:new).and_yield
  end

  describe '#listen' do
    after { realtime_client.running = false }

    it 'parses SSE data and calls update_environment when updated_at increases' do
      expect(mock_main).to receive(:update_environment).twice
      realtime_client.listen(mock_main, retry_interval: retry_interval, remaining_attempts: 3)
    end

    it 'logs retries and continues on connection failure' do
      allow(Faraday).to receive(:new).and_raise(Faraday::ConnectionFailed.new('Connection failed'))

      expect(mock_logger).to receive(:warn).with(/Connection failed/).at_least(:once)
      realtime_client.listen(mock_main, retry_interval: retry_interval, remaining_attempts: 3)
      end

    it 'handles and logs unexpected errors gracefully' do
      allow(Faraday).to receive(:new).and_raise(StandardError.new('Unexpected error'))

      expect(mock_logger).to receive(:error).with(/Unexpected error/).at_least(:once)
      realtime_client.listen(mock_main, retry_interval: retry_interval, remaining_attempts: 3)
    end

    context 'when the events arrive split across chunks' do
      let(:stream_chunks) { ['data: {"updated', "_at\": 1}\n\ndata: {\"updated_at\": 2}\n", "\n"] }

      it 'reassembles the lines before parsing them' do
        expect(mock_logger).not_to receive(:error)
        realtime_client.listen(mock_main, retry_interval: retry_interval, remaining_attempts: 1)
        expect(update_count[0]).to eq(2)
      end
    end

    context 'with a real background thread' do
      before { allow(Thread).to receive(:new).and_call_original }

      def wait_for_listener
        realtime_client.instance_variable_get(:@thread).join(5)
      end

      it 'stays running and reconnects after the stream is closed' do
        realtime_client.listen(mock_main, retry_interval: retry_interval, remaining_attempts: 3)
        expect(realtime_client.running).to be(true)

        wait_for_listener
        expect(connection_count[0]).to eq(3)
        expect(realtime_client.running).to be(false)
      end

      it 'updates the environment while the stream is still open' do
        realtime_client.listen(mock_main, retry_interval: retry_interval, remaining_attempts: 1)
        wait_for_listener

        expect(updates_seen_while_connected).to eq([2])
      end
    end
  end
end

RSpec.describe Flagsmith::Client do
  describe '#initialize' do
    before do
      # Mock the methods to avoid initialization interferring.
      allow_any_instance_of(Flagsmith::Client).to receive(:api_client)
      allow_any_instance_of(Flagsmith::Client).to receive(:analytics_processor)
      allow_any_instance_of(Flagsmith::Client).to receive(:event_processor)
      allow_any_instance_of(Flagsmith::Client).to receive(:environment_data_polling_manager)
      allow_any_instance_of(Flagsmith::Client).to receive(:engine)
      allow_any_instance_of(Flagsmith::Client).to receive(:load_offline_handler)
    end

    context 'when realtime_mode is true and local_evaluation is false' do
      it 'raises a Flagsmith::ClientError' do
        config = double(
          'Config',
          realtime_mode?: true,
          local_evaluation?: false,
          offline_mode?: false,
          offline_handler: nil,
        )
        allow(Flagsmith::Config).to receive(:new).and_return(config)

        expect {
          Flagsmith::Client.new(config)
        }.to raise_error(Flagsmith::ClientError, 'The enable_realtime_updates config param requires a matching enable_local_evaluation param.')
      end
    end

    context 'when realtime_mode is false or local_evaluation is true' do
      it 'does not raise an exception' do
        config = double(
          'Config',
          realtime_mode?: false,
          local_evaluation?: true,
          offline_mode?: false,
          offline_handler: nil,
        )
        allow(Flagsmith::Config).to receive(:new).and_return(config)

        expect {
          Flagsmith::Client.new(config)
        }.not_to raise_error
      end
    end
  end
end
