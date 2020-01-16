# frozen_string_literal: true

require_relative '../lib/bullet_train'
require 'ostruct'
require 'json'

describe BulletTrain do
  let(:mock_faraday) { double(Faraday) }
  let(:mock_api_key) { 'ASDFIEVNQWEPARJ' }
  let(:mock_api_url) { 'http://mock.bullet-train.io/api/' }
  let(:user_id) { 'user@email.none' }
  let(:api_flags_response) { File.read('spec/fixtures/GET_flags.json') }
  let(:api_identities_response) { File.read('spec/fixtures/GET_identities_user.json') }
  let(:flags_response) { OpenStruct.new(body: JSON.parse(api_flags_response)) }
  let(:identities_response) { OpenStruct.new(body: JSON.parse(api_identities_response)) }

  before do
    allow(Faraday).to receive(:new).with(url: mock_api_url).and_return(mock_faraday)
    allow(mock_faraday).to receive(:get).with('flags/').and_return(flags_response)
    allow(mock_faraday).to receive(:get).with("identities/?identifier=#{user_id}").and_return(identities_response)
  end
  subject { BulletTrain.new(api_key: mock_api_key, url: mock_api_url) }

  describe '#get_flags' do
    it 'should return all flags without a segment' do
      expect(flags_response.body.length).to eq(4)
      flags = subject.get_flags(nil)
      expect(flags.length).to eq(3)
      expect(flags['feature_three'][:enabled]).to eq(false)
    end

    context 'with user_id' do
      it 'should return all flags adjusted for segments' do
        flags = subject.get_flags(user_id)
        expect(flags.length).to eq(3)
        expect(flags['feature_three'][:enabled]).to eq(true)
      end
    end
  end

  describe '#feature_enabled?' do
    it 'checks a specific feature' do
      expect(subject.feature_enabled?(:feature_one)).to eq(false)
      expect(subject.feature_enabled?('feature_two')).to eq(true)
      expect(subject.feature_enabled?('Feature_THREE')).to eq(false)
    end

    context 'with user_id' do
      it 'checks a specific feature for a given user' do
        expect(subject.feature_enabled?(:feature_one, user_id)).to eq(false)
        expect(subject.feature_enabled?('feature_two', user_id)).to eq(true)
        expect(subject.feature_enabled?(:feature_three, user_id)).to eq(true)
      end
    end
  end

  describe '#get_value' do
    it 'returns a value from a key' do
      expect(subject.get_value(:feature_one)).to be_nil
      expect(subject.get_value(:feature_two)).to eq(42)
      expect(subject.get_value(:feature_three)).to be_nil
    end

    context 'with user_id' do
      it 'returns a value for that user' do
        expect(subject.get_value(:feature_one, user_id)).to be_nil
        expect(subject.get_value(:feature_two, user_id)).to eq(42)
        expect(subject.get_value(:feature_three, user_id)).to eq(7)
      end
    end
  end

  describe '#set_trait' do
    let(:trait_key) { 'foo' }
    let(:trait_value) { 'bar' }
    let(:post_body) do
      {
        identity: { identifier: user_id },
        trait_key: subject.normalize_key(trait_key),
        trait_value: trait_value
      }.to_json
    end

    it 'sets a trait for a given user' do
      trait_response = OpenStruct.new(body: {})
      expect(mock_faraday).to receive(:post).with('traits/', post_body).and_return(trait_response)
      subject.set_trait user_id, trait_key, trait_value
    end

    it 'errors if user_id.nil?' do
      expect { subject.set_trait nil, trait_key, trait_value }.to raise_error(StandardError)
    end
  end

  describe '#get_traits' do
    it 'returns hash of traits for a given user' do
      traits = subject.get_traits(user_id)
      expect(traits['roles']).to eq(%w[admin staff].to_json)
      expect(traits.length).to eq(2)
    end
    it 'returns {} for user_id.nil?' do
      expect(subject.get_traits(nil)).to eq({})
    end
  end

  describe '#normalize_key' do
    it 'returns an empty string given nil' do
      expect(subject.normalize_key(nil)).to eq('')
    end

    it 'returns lower case string given a symbol' do
      expect(subject.normalize_key(:key_value)).to eq('key_value')
    end

    it 'returns lower case string given a mixed case string' do
      expect(subject.normalize_key('KEY_VaLuE')).to eq('key_value')
    end
  end

  describe 'maintain backward compatibility with non-idiomatic ruby' do
    it 'aliases hasFeature' do
      expect(subject.method(:hasFeature)).to eq(subject.method(:feature_enabled?))
    end

    it 'aliases getValue' do
      expect(subject.method(:getValue)).to eq(subject.method(:get_value))
    end

    it 'aliases getFlags'do
      expect(subject.method(:getFlags)).to eq(subject.method(:get_flags))
    end

    it 'aliases getFlagsForUser'do
      expect(subject.method(:getFlagsForUser)).to eq(subject.method(:get_flags))
    end
  end
end
