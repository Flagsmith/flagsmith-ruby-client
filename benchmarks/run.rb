# frozen_string_literal: true

# Runs every SDK benchmark in a single process, measuring only the benchmarked calls.
#
# Under the CodSpeed runner, each call is measured with instrument-hooks, so Ruby start-up,
# loading the SDK and building the client stay out of the results. Elsewhere, it prints timings.
require 'bundler/setup'
require 'benchmark'
require 'rbconfig'
require_relative 'sdk_benchmark'

LOCAL_REVOLUTIONS = 100

sdk_benchmarks_dir = ENV.fetch('SDK_BENCHMARKS', '')
if sdk_benchmarks_dir.empty?
  warn "Usage: SDK_BENCHMARKS=<dir> ruby #{$PROGRAM_NAME}"
  exit 2
end

codspeed = !ENV.fetch('CODSPEED_ENV', '').empty?
if codspeed
  require_relative '../tmp/codspeed/codspeed'
  abort 'CodSpeed: not running under instrumentation' unless CodSpeed.instrumented?
  libruby = File.join(RbConfig::CONFIG['libdir'], RbConfig::CONFIG['LIBRUBY_SO'])
  CodSpeed.setup('flagsmith-ruby-client', Flagsmith::VERSION, [RbConfig.ruby, libruby].select { File.exist?(_1) })
end

SdkBenchmark::ENVIRONMENTS.each do |environment|
  sdk_benchmark = SdkBenchmark.new(sdk_benchmarks_dir, environment)
  SdkBenchmark::BENCHMARKS.each do |name, method|
    sdk_benchmark.public_send(method) # Warm up caches
    if codspeed
      GC.start
      CodSpeed.measure("benchmarks/sdk_benchmark.rb::#{name}[#{environment}]") { sdk_benchmark.public_send(method) }
    else
      seconds = Benchmark.realtime { LOCAL_REVOLUTIONS.times { sdk_benchmark.public_send(method) } }
      puts format('%<name>-50s %<ms>10.3f ms', name: "#{name}[#{environment}]", ms: seconds * 1000 / LOCAL_REVOLUTIONS)
    end
  end
  sdk_benchmark.close
end
