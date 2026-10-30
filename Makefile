SDK_BENCHMARKS := spec/sdk-benchmarks
CODSPEED_VERSION := 5.6.0
CODSPEED_INSTALLER_SHA256 := bf1bf63661e203bcabc0c84fdef0337f8658fc8340c467a6a3bca81040d99f40

$(SDK_BENCHMARKS)/environments:
	git submodule update --init -- $(SDK_BENCHMARKS)

.PHONY: install-codspeed
install-codspeed: $(SDK_BENCHMARKS)/environments
	bundle install
	installer=$$(mktemp) && \
	curl -fsSL -o "$$installer" "https://codspeed.io/v$(CODSPEED_VERSION)/install.sh" && \
	echo "$(CODSPEED_INSTALLER_SHA256)  $$installer" | sha256sum --check --strict && \
	bash "$$installer" --quiet

.PHONY: benchmark
benchmark: install-codspeed
	SDK_BENCHMARKS=$(SDK_BENCHMARKS) codspeed run --mode simulation --config codspeed.yml
