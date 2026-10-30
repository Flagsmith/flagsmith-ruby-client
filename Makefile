SDK_BENCHMARKS := spec/sdk-benchmarks
CODSPEED_VERSION := 5.6.0
CODSPEED_INSTALLER_SHA256 := bf1bf63661e203bcabc0c84fdef0337f8658fc8340c467a6a3bca81040d99f40

INSTRUMENT_HOOKS := benchmarks/codspeed/instrument-hooks
CODSPEED_EXT := tmp/codspeed/codspeed.$(shell ruby -e 'print RbConfig::CONFIG["DLEXT"]')

$(SDK_BENCHMARKS)/environments:
	git submodule update --init -- $(SDK_BENCHMARKS)

$(INSTRUMENT_HOOKS)/dist/core.c:
	git submodule update --init -- $(INSTRUMENT_HOOKS)

$(CODSPEED_EXT): benchmarks/codspeed/codspeed.c benchmarks/codspeed/extconf.rb $(INSTRUMENT_HOOKS)/dist/core.c
	mkdir -p $(@D)
	cd $(@D) && ruby $(CURDIR)/benchmarks/codspeed/extconf.rb && $(MAKE)

.PHONY: install-codspeed
install-codspeed: $(SDK_BENCHMARKS)/environments
	bundle install
	installer=$$(mktemp) && \
	curl -fsSL -o "$$installer" "https://codspeed.io/v$(CODSPEED_VERSION)/install.sh" && \
	echo "$(CODSPEED_INSTALLER_SHA256)  $$installer" | sha256sum --check --strict && \
	bash "$$installer" --quiet

.PHONY: benchmark
benchmark: install-codspeed $(CODSPEED_EXT)
	SDK_BENCHMARKS=$(SDK_BENCHMARKS) codspeed run --mode simulation --config codspeed.yml
