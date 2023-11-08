# frozen_string_literal: true

require "prometheus/middleware/exporter"
require 'prometheus/client/formats/text'
require 'logger'
require 'webrick'
require "rack"

module BM
  module Instrumentations
    module Exporter
      class Server < ::Prometheus::Middleware::Exporter
        NOT_FOUND_HANDLER = lambda do |_env|
          [404, { "Content-Type" => "text/plain" }, ["Not Found\n"]]
        end.freeze

        class << self
          # Allows to use middleware as standalone rack application
          def call(env)
            options = env.fetch("action_dispatch.request.path_parameters", {})
            @app ||= new(NOT_FOUND_HANDLER, path: "/", **options)
            @app.call(env)
          end

          def start_metrics_server!(**rack_app_options)
            Thread.new do
              default_port = ENV.fetch("PORT", 9394)
              ::Rack::Handler::WEBrick.run(
                rack_app(**rack_app_options),
                Host: ENV["PROMETHEUS_EXPORTER_BIND"] || "0.0.0.0",
                Port: ENV.fetch("PROMETHEUS_EXPORTER_PORT", default_port),
                AccessLog: [],
              )
            end
          end

          def rack_app(exporter = self, logger: Logger.new(IO::NULL), use_deflater: true, **exporter_options)
            ::Rack::Builder.new do
              use ::Rack::Deflater if use_deflater
              use ::Rack::CommonLogger, logger
              use ::Rack::ShowExceptions
              use exporter, **exporter_options
              run NOT_FOUND_HANDLER
            end
          end
        end

        def initialize(app, options = {})
          super(app, options.merge(registry: Prometheus::Client.registry))
        end
  
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
