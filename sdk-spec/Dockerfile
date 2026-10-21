# Runs this SDK, built from source, under the Flagsmith SDK behavioural spec.
# docker build -f sdk-spec/Dockerfile --build-context harness=<sdk-spec>/harness/ruby .
FROM docker.io/library/ruby:3.3-slim

# The gemspec lists its files with `git ls-files`.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /sdk
COPY . .
RUN gem build flagsmith.gemspec --output flagsmith.gem \
    && gem install --no-document flagsmith.gem

COPY --from=harness harness.rb /harness/harness.rb

ENTRYPOINT ["ruby", "/harness/harness.rb", "sdk-spec/steps.rb"]
