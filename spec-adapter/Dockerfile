# Builds the SDK from source with the adapter for the Flagsmith SDK behavioural spec.
# Build from the repository root: docker build -f spec-adapter/Dockerfile .
FROM ruby:3.3-slim

# The gemspec lists its files with `git ls-files`.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /sdk
COPY . .
RUN gem build flagsmith.gemspec --output flagsmith.gem \
    && gem install --no-document flagsmith.gem webrick

ENV PORT=8080
EXPOSE 8080
CMD ["ruby", "spec-adapter/adapter.rb"]
