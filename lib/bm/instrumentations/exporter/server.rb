# frozen_string_literal: true

require 'rack'
require 'logger'
require 'prometheus/client/formats/text'

module BM
  module Instrumentations
    module Exporter

      # The `exporter_server` provides monitoring and metrics on different HTTP port.
      #
      # The server exposes a few endpoints:
      # * `/ping` - a liveness probe, always return `HTTP 200 OK` when the server is running
      # * `/metrics` - metrics list from the current Prometheus registry
      # * `/gc-status` - print ruby GC statistics as JSON
      # * `/threads` - print running threads, names and backtraces as JSON
      class Server

        # Rack application entry point for the management server
        def self.call(env)
          new(env).response.finish
        end

        def initialize(env)
          @env = env
        end

        def response
          case @env['PATH_INFO']
          when '/ping'
            Rack::Response.new('pong', 200, 'Content-Type' => 'text/plain')
          when '/metrics'
            metrics
          when '/gc-stats'
            gc_stats
          when '/threads'
            threads
          else
            Rack::Response.new('Not Found', 404, 'Content-Type' => 'text/plain')
          end
        end

        private

        def metrics
          # Assuming you have a method to collect metrics
          # Implement your logic to return metrics here
          text = Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)
          Rack::Response.new(text, 200, 'Content-Type' => Prometheus::Client::Formats::Text::CONTENT_TYPE)
        end

        def gc_stats
          # Implement your logic to return GC stats here
          stats = GC.stat.to_json
          Rack::Response.new(stats, 200, 'Content-Type' => 'application/json')
        end

        def threads
          # Implement your logic to return thread info here
          thread_info = Thread.list.map { |t| { name: t.name, backtrace: t.backtrace } }.to_json
          Rack::Response.new(thread_info, 200, 'Content-Type' => 'application/json')
        end
      end
    end
  end
end
