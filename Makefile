SDK_BENCHMARKS := spec/sdk-benchmarks

$(SDK_BENCHMARKS)/environments:
	git submodule update --init -- $(SDK_BENCHMARKS)

.PHONY: benchmark-deps
benchmark-deps: $(SDK_BENCHMARKS)/environments
	bundle install

.PHONY: benchmark
benchmark: benchmark-deps
	SDK_BENCHMARKS=$(SDK_BENCHMARKS) codspeed run --mode walltime --config codspeed.yml
