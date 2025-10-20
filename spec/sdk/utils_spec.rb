# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Flagsmith::SDK::Utils do
  describe '.user_agent' do
    it 'returns user agent with version' do
      expected_user_agent = "flagsmith-ruby-sdk/#{Flagsmith::VERSION}"
      expect(described_class.user_agent).to eq(expected_user_agent)
    end

    it 'includes the correct format' do
      user_agent = described_class.user_agent
      expect(user_agent).to match(/^flagsmith-ruby-sdk\/\d+\.\d+\.\d+$/)
    end
  end

  describe '.version' do
    it 'returns the Flagsmith version' do
      expect(described_class.version).to eq(Flagsmith::VERSION)
    end

    it 'returns a non-empty string' do
      expect(described_class.version).to be_a(String)
      expect(described_class.version).not_to be_empty
    end

    context 'when VERSION constant is not available' do
      it 'returns unknown as fallback' do
        version_backup = Flagsmith::VERSION
        Flagsmith.send(:remove_const, :VERSION)

        expect(described_class.version).to eq('unknown')

        Flagsmith.const_set(:VERSION, version_backup)
      end
    end
  end
end
