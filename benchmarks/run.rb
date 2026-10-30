# frozen_string_literal: true

require 'bundler/setup'
require_relative 'sdk_benchmark'

REVOLUTIONS = 10

benchmark, environment = ARGV
sdk_benchmarks_dir = ENV.fetch('SDK_BENCHMARKS', '')

unless !sdk_benchmarks_dir.empty? && SdkBenchmark::BENCHMARKS.key?(benchmark) && SdkBenchmark::ENVIRONMENTS.include?(environment)
  warn "Usage: SDK_BENCHMARKS=<dir> ruby #{$PROGRAM_NAME} " \
       "<#{SdkBenchmark::BENCHMARKS.keys.join('|')}> <#{SdkBenchmark::ENVIRONMENTS.join('|')}>"
  exit 2
end

sdk_benchmark = SdkBenchmark.new(sdk_benchmarks_dir, environment)
REVOLUTIONS.times { sdk_benchmark.public_send(SdkBenchmark::BENCHMARKS.fetch(benchmark)) }
sdk_benchmark.close
