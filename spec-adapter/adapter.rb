# frozen_string_literal: true

# Adapter that lets the Flagsmith SDK behavioural spec drive this SDK.
#
# Protocol: https://github.com/Flagsmith/sdk-spec/blob/main/ADAPTER.md

require 'json'
require 'webrick'
require 'flagsmith'

CLIENT_ROUTE = %r{\A/clients/(?<client_id>[^/]+)(?<action>/[a-z-]+)?\z}

$stdout.sync = true

# Serves the adapter protocol, keeping one SDK client per spec scenario.
class Adapter
  def initialize
    @clients = {}
    @next_client_id = 0
    @mutex = Mutex.new
  end

  def call(request, response)
    status, body = begin
      route(request)
    rescue StandardError => e # report SDK errors to the runner
      warn e.full_message
      [500, { error: "#{e.class}: #{e.message}" }]
    end
    response.status = status
    response['Content-Type'] = 'application/json'
    response.body = body.nil? ? '' : JSON.generate(body)
  end

  private

  def route(request)
    method = request.request_method
    path = request.path
    return [200, { sdk: 'flagsmith-ruby-client', version: Flagsmith::VERSION }] if method == 'GET' && path == '/health'
    return create_client(parse_body(request)) if method == 'POST' && path == '/clients'

    match = CLIENT_ROUTE.match(path)
    client = match && @mutex.synchronize { @clients[match[:client_id]] }
    return not_found(request) unless client

    route_client(request, match[:client_id], match[:action], client)
  end

  def route_client(request, client_id, action, client)
    case [request.request_method, action]
    when ['DELETE', nil] then delete_client(client_id)
    when ['POST', '/environment-flags'] then [200, serialise_flags(client.get_environment_flags)]
    when ['POST', '/identity-flags'] then [200, serialise_flags(identity_flags(client, parse_body(request)))]
    else not_found(request)
    end
  end

  def create_client(body)
    client = Flagsmith::Client.new(environment_key: body['environmentKey'], api_url: body['apiUrl'])
    client_id = @mutex.synchronize { (@next_client_id += 1).to_s.tap { |id| @clients[id] = client } }
    [201, { clientId: client_id }]
  end

  def delete_client(client_id)
    @mutex.synchronize { @clients.delete(client_id) }
    [204, nil]
  end

  def identity_flags(client, body)
    client.get_identity_flags(body['identifier'], **(body['traits'] || {}))
  end

  def serialise_flags(flags)
    {
      flags: flags.all_flags.map do |flag|
        { featureName: flag.feature_name, enabled: flag.enabled, value: flag.value }
      end
    }
  end

  def parse_body(request)
    request.body.to_s.empty? ? {} : JSON.parse(request.body)
  end

  def not_found(request)
    [404, { error: "No route for #{request.request_method} #{request.path}" }]
  end
end

# Hands every request to the adapter, whatever its method.
class Servlet < WEBrick::HTTPServlet::AbstractServlet
  def initialize(server, adapter)
    super
    @adapter = adapter
  end

  def service(request, response)
    @adapter.call(request, response)
  end
end

if $PROGRAM_NAME == __FILE__
  port = Integer(ENV.fetch('PORT', '8080'))
  server = WEBrick::HTTPServer.new(BindAddress: '0.0.0.0', Port: port)
  server.mount('/', Servlet, Adapter.new)
  trap('TERM') { server.shutdown }
  trap('INT') { server.shutdown }
  server.start
end
