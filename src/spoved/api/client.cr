require "../logger"
require "../error"

require "halite"
require "../../ext/halite"

module Spoved
  class Api
    # The `Spoved::Api::Client` is meant to help make the creation of REST API clients easier. It contains abstracted
    # methods and features that are common between most RESTful apis.
    #
    # ```
    # client = Spoved::Api::Client.new("jsonplaceholder.typicode.com", scheme: "https", api_path: "")
    # ```
    class Client
      spoved_logger

      macro inherited
        spoved_logger
      end

      property scheme : String = "https"
      property host : String
      property port : Int32?
      property api_path : String = "api/v1"
      property read_timeout : Int32? = nil

      property default_headers : Hash(String, String) = {
        "Content-Type" => "application/json",
        "Accept"       => "application/json",
      }

      getter stream = Channel(String).new
      getter tls_client = OpenSSL::SSL::Context::Client.new

      macro inherited
        def self.new(uri : URI, **args)
          instance = {{@type.name.id}}.allocate
          instance.initialize(
            **args,
            host: uri.host.as(String),
            port: uri.port,
            scheme: uri.scheme.as(String),
          )
          instance
        end
      end

      # TODO: do correct tsl verification
      def initialize(
        @host : String, @port : Int32? = nil,
        @user : String? = nil, @pass : String? = nil,
        @scheme = "https", @api_path = "api/v1",
        tls_verify_mode = OpenSSL::SSL::VerifyMode::PEER,
        **other
      )
        @tls_client.verify_mode = tls_verify_mode
        @read_timeout = other[:read_timeout]?
        @default_headers = other[:default_headers]?.as(Hash(String, String)) if other[:default_headers]?

        if other[:ssl_private_key]?
          path = File.expand_path(other[:ssl_private_key]?.as(String))
          tls_client.private_key = path if File.exists?(path)
        end
      end

      # URI helper function
      def make_request_uri(path : String, params : String? = nil) : URI
        if (api_path.empty?)
          URI.new(scheme: scheme, host: host, path: "/#{path}", query: params.to_s, port: port)
        else
          URI.new(scheme: scheme, host: host, path: "/#{api_path}/#{path}", query: params.to_s, port: port)
        end
      end

      private def format_params(params)
        args = HTTP::Params.build do |form|
          params.each do |k, v|
            form.add k, v
          end
        end
        args
      end

      def https?
        scheme == "https"
      end

      def http?
        scheme == "http"
      end

      # Wrapper to return tls only if scheme is https
      private def tls : OpenSSL::SSL::Context::Client?
        https? ? @tls_client : nil
      end

      private def halite
        user = @user
        pass = @pass
        h = if !user.nil? && !pass.nil?
              Halite.basic_auth(user: user, pass: pass)
            else
              Halite::Client.new
            end

        if read_timeout.nil?
          h
        else
          h.timeout(read: read_timeout.not_nil!.seconds)
        end
      end
    end
  end
end

require "./client/*"
