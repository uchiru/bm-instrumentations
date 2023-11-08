# exporter_server.rb

require 'webrick'
require 'rack'
require 'logger'
require 'prometheus/client/formats/text'

module BM
  module Instrumentations
    module Exporter

      class Server
        # Initializes a new instance of the Server class
        def initialize(env)
          @env = env
        end

        # Responds to a Rack request
        def call(env)
          case env['PATH_INFO']
          when '/ping'
            response('pong', 200, 'text/plain')
          when '/metrics'
            metrics
          when '/gc-stats'
            gc_stats
          when '/threads'
            threads
          else
            response('Not Found', 404, 'text/plain')
          end
        end

        # Starts a WEBrick server on the specified port
        def self.start_webrick(port: 9990, host: '0.0.0.0', logger: Logger.new($stdout))
          server = WEBrick::HTTPServer.new(
            Port: port,
            Host: host,
            Logger: logger,
            AccessLog: []
          )

          server.mount_proc '/' do |req, res|
            rack_env = Rack::MockRequest.env_for(req.request_uri.to_s, { method: req.request_method })
            status, headers, body = new.call(rack_env)
            
            res.status = status
            headers.each { |k, v| res[k] = v }
            body.each { |part| res.body << part }
            
            body.close if body.respond_to?(:close)
          end

          trap('INT') { server.shutdown }
          server.start
        end

        private

        # Helper method to construct a Rack response
        def response(body, status, content_type)
          [status, { 'Content-Type' => content_type }, [body]]
        end

        # Collects metrics and constructs a Rack response
        def metrics
          text = Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)
          response(text, 200, Prometheus::Client::Formats::Text::CONTENT_TYPE)
        end

        # Collects GC stats and constructs a Rack response
        def gc_stats
          stats = GC.stat.to_json
          response(stats, 200, 'application/json')
        end

        # Collects thread info and constructs a Rack response
        def threads
          thread_info = Thread.list.map { |t| { name: t.name, backtrace: t.backtrace } }.to_json
          response(thread_info, 200, 'application/json')
        end
      end
    end
  end
end
