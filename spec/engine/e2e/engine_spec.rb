# frozen_string_literal: true

require 'spec_helper'

def get_test_files
  test_data_dir = File.join(APP_ROOT, 'spec/engine-test-data/test_cases')
  Dir.glob(File.join(test_data_dir, '*.{json,jsonc}')).sort
end

def parse_jsonc(content)
  # Simple JSONC parser: remove single-line comments
  # JSON.parse will handle the rest
  cleaned = content.lines.reject { |line| line.strip.start_with?('//') }.join
  JSON.parse(cleaned, symbolize_names: true)
end

def load_test_file(filepath)
  content = File.read(filepath)
  parse_jsonc(content)
end

RSpec.describe Flagsmith::Engine do
  test_files = get_test_files

  raise "No test files found" if test_files.empty?

  test_files.each do |filepath|
    test_name = File.basename(filepath, File.extname(filepath))

    describe test_name do
      it 'should produce the expected evaluation result' do
        test_case = load_test_file(filepath)

        test_evaluation_context = test_case[:context]
        test_expected_result = test_case[:result]

        # TODO: Implement evaluation logic
        evaluation_result = Flagsmith::Engine::Evaluation::Core.get_evaluation_result(test_evaluation_context)


        # TODO: Uncomment when evaluation is implemented
        expect(evaluation_result[:flags]).to eq(test_expected_result[:flags])
      end
    end
  end
end
