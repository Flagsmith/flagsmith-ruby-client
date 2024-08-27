# frozen_string_literal: true

require 'spec_helper'

require_relative 'shared_mocks.rb'

RSpec.describe Flagsmith do
  include_context 'shared mocks'

  subject { flagsmith }

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

  describe '#normalize_key' do
    it 'returns an empty string given nil' do
      expect(Flagsmith::Flags::Collection.normalize_key(nil)).to eq('')
    end

    it 'returns lower case string given a symbol' do
      expect(Flagsmith::Flags::Collection.normalize_key(:key_value)).to eq('key_value')
    end

    it 'returns lower case string given a mixed case string' do
      expect(Flagsmith::Flags::Collection.normalize_key('KEY_VaLuE')).to eq('key_value')
    end
  end

  describe '#get_identity_segments' do
    it 'returns an empty list given an identity which matches no segment conditions' do
      polling_manager = Flagsmith::EnvironmentDataPollingManager.new(subject, 60, 10)
      subject.update_environment()
      expect(subject.get_identity_segments("identifier")).to eq([])
    end

    it 'returns the relevant segment given an identity with matching traits' do
      polling_manager = Flagsmith::EnvironmentDataPollingManager.new(subject, 60, 10)
      subject.update_environment()
      expect(subject.get_identity_segments("identifier", {"age": 39}).length).to eq(1)
    end
  end

  describe '#get_identity_flags' do
    context 'with transient identity' do
      before {
        transient_identities_response = OpenStruct.new(body: { **identities_response.body } )
        transient_identities_response.body[:traits] = identities_response.body[:traits].map{ |api_trait| { **api_trait, transient: true } }
        allow(mock_api_client).to receive(:post).with(
          'identities/', { identifier: user_id, transient: true, traits: [] }.to_json
        ).and_return(transient_identities_response)    
      }

      it 'sends expected request' do
        flags = subject.get_identity_flags(user_id, true)
        expect(flags.feature_enabled?(:feature_one)).to eq(false)
        expect(flags.feature_enabled?('feature_two')).to eq(true)
        expect(flags.feature_enabled?(:feature_three)).to eq(true)
      end
    end

    context 'with transient trait' do 
      before {
        transient_trait_data = { trait_key: "age", trait_value: 42, transient: true }
        transient_traits_response = OpenStruct.new(body: { **identities_response.body } )
        transient_traits_response.body[:traits] = transient_traits_response.body[:traits] + [transient_trait_data]
        allow(mock_api_client).to receive(:post).with(
          'identities/', { identifier: user_id, transient: false, traits: [transient_trait_data] }.to_json
        ).and_return(transient_traits_response)    
      }

      it 'sends expected request' do
        flags = subject.get_identity_flags(user_id, age: { value: 42, transient: true })
        expect(flags.feature_enabled?(:feature_one)).to eq(false)
        expect(flags.feature_enabled?('feature_two')).to eq(true)
        expect(flags.feature_enabled?(:feature_three)).to eq(true)
      end
    end
  end
end
