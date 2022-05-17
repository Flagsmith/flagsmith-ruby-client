# frozen_string_literal: true

require_relative '../lib/flagsmith'
require 'ostruct'
require 'json'

describe Flagsmith do
  let(:mock_api_client) { double(Flagsmiths::ApiClient) }
  let(:mock_config) { double(Flagsmiths::Config) }
  let(:mock_api_key) { 'ASDFIEVNQWEPARJ' }
  let(:mock_api_url) { 'http://mock.flagsmith.com/api/' }
  let(:user_id) { 'user@email.none' }
  let(:api_flags_response) { File.read('spec/fixtures/GET_flags.json') }
  let(:api_identities_response) { File.read('spec/fixtures/GET_identities_user.json') }
  let(:flags_response) { OpenStruct.new(body: JSON.parse(api_flags_response)) }
  let(:identities_response) { OpenStruct.new(body: JSON.parse(api_identities_response)) }

  before do
    allow(Flagsmiths::Config).to receive(:new).with(api_url: mock_api_url, environment_key: mock_api_key)
                                              .and_return(mock_config)
    allow(mock_config).to receive(:enable_analytics?).and_return(false)
    allow(mock_config).to receive(:local_evaluation?).and_return(false)
    allow(mock_config).to receive(:default_flag_handler).and_return(nil)
    allow(mock_config).to receive(:identities_url).and_return('identities/')
    allow(mock_config).to receive(:environment_flags_url).and_return('flags/')
    allow(Flagsmiths::ApiClient).to receive(:new).with(mock_config)
                                                 .and_return(mock_api_client)
    allow(mock_api_client).to receive(:get).with('flags/').and_return(flags_response)
    allow(mock_api_client).to receive(:post).with(
      'identities/', { identifier: user_id, traits: [] }.to_json
    ).and_return(identities_response)
  end
  subject { Flagsmith.new(environment_key: mock_api_key, api_url: mock_api_url) }

  describe '#get_flags' do
    it 'should return all flags without a segment' do
      expect(flags_response.body.length).to eq(4)
      flags = subject.get_environment_flags
      expect(flags.length).to eq(3)
      expect(flags.feature_enabled?('feature_three')).to eq(false)
    end

    context 'with user_id' do
      it 'should return all flags adjusted for segments' do
        flags = subject.get_identity_flags(user_id)
        expect(flags.length).to eq(3)
        expect(flags.feature_enabled?('feature_three')).to eq(true)
      end
    end
  end

  describe '#feature_enabled?' do
    it 'checks a specific feature' do
      flags = subject.get_environment_flags
      expect(flags.feature_enabled?(:feature_one)).to eq(false)
      expect(flags.feature_enabled?('feature_two')).to eq(true)
      expect(flags.feature_enabled?('Feature_THREE')).to eq(false)
    end

    context 'with user_id' do
      it 'checks a specific feature for a given user' do
        flags = subject.get_identity_flags(user_id)
        expect(flags.feature_enabled?(:feature_one)).to eq(false)
        expect(flags.feature_enabled?('feature_two')).to eq(true)
        expect(flags.feature_enabled?(:feature_three)).to eq(true)
      end
    end
  end

  describe '#get_value' do
    it 'returns a value from a key' do
      flags = subject.get_environment_flags
      expect(flags.feature_value(:feature_one)).to be_nil
      expect(flags.feature_value(:feature_two)).to eq(42)
      expect(flags.feature_value(:feature_three)).to be_nil
    end

    context 'with user_id' do
      it 'returns a value for that user' do
        flags = subject.get_identity_flags(user_id)
        expect(flags.feature_value(:feature_one)).to be_nil
        expect(flags.feature_value(:feature_two)).to eq(42)
        expect(flags.feature_value(:feature_three)).to eq(7)
      end
    end
  end

  # describe '#set_trait' do
  #   let(:trait_key) { 'foo' }
  #   let(:trait_value) { 'bar' }
  #   let(:post_body) do
  #     {
  #       identity: { identifier: user_id },
  #       trait_key: Flagsmiths::Flags::Collection.normalize_key(trait_key),
  #       trait_value: trait_value
  #     }.to_json
  #   end
  #
  #   it 'sets a trait for a given user' do
  #     trait_response = OpenStruct.new(body: {})
  #     expect(mock_api_client).to receive(:post).with('traits/', post_body).and_return(trait_response)
  #     subject.set_trait user_id, trait_key, trait_value
  #   end
  #
  #   it 'errors if user_id.nil?' do
  #     expect { subject.set_trait nil, trait_key, trait_value }.to raise_error(StandardError)
  #   end
  # end

  # describe '#get_traits' do
  #   it 'returns hash of traits for a given user' do
  #     traits = subject.get_traits(user_id)
  #     expect(traits['roles']).to eq(%w[admin staff].to_json)
  #     expect(traits.length).to eq(2)
  #   end
  #   it 'returns {} for user_id.nil?' do
  #     expect(subject.get_traits(nil)).to eq({})
  #   end
  # end

  describe '#normalize_key' do
    it 'returns an empty string given nil' do
      expect(Flagsmiths::Flags::Collection.normalize_key(nil)).to eq('')
    end

    it 'returns lower case string given a symbol' do
      expect(Flagsmiths::Flags::Collection.normalize_key(:key_value)).to eq('key_value')
    end

    it 'returns lower case string given a mixed case string' do
      expect(Flagsmiths::Flags::Collection.normalize_key('KEY_VaLuE')).to eq('key_value')
    end
  end
end
