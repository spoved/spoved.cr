require "../logger"
require "../error"

require "halite"

module Spoved
  class Api
    # The `Spoved::Api::Client` is meant to help make the creation of REST API clients easier. It contains abstracted
    # methods and features that are common between most RESTful apis.
    #
    # ```
    # client = Spoved::Api::Client.new("jsonplaceholder.typicode.com", scheme: "https", api_path: "")
    #
    class Client
      spoved_logger

      property scheme : String
      property host : String
      property port : Int32?
      property api_path : String
      property default_headers : Hash(String, String)
      getter stream = Channel(String).new

      @default_headers = {
        "Content-Type" => "application/json",
        "Accept"       => "application/json",
      }

      # TODO: do correct tsl verification
      def initialize(
        @host : String, @port : Int32? = nil,
        @user : String? = nil, @pass : String? = nil,
        logger : Logger? = nil,
        @scheme = "https", @api_path = "api/v1",
        tls_verify_mode = OpenSSL::SSL::VerifyMode::PEER
      )
        @tls_client = OpenSSL::SSL::Context::Client.new
        @tls_client.verify_mode = tls_verify_mode
        if logger
          self.logger = logger
        end
      end

      # URI helper function
      def make_request_uri(path : String, params : String | Nil = nil) : URI
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

      # Make a GET request
      def get(path : String, params : Hash(String, String))
        get(path, format_params(params))
      end

      def stream_get(path : String, params : Hash(String, String))
        resp = halite.get(make_request_uri(path, format_params(params)).to_s,
          headers: default_headers, tls: @tls_client) do |response|
          spawn do
            logger.warn("Spawn #{stream} start")
            while !stream.closed?
              response.body_io.each_line do |line|
                stream.send(line)
              end
            end
            logger.warn("Spawn #{stream} end")
          end
        end
      end

      # Make a DELETE request
      def delete(path : String, params : String | Nil = nil)
        make_delete_request(make_request_uri(path, params))
      end

      # Make a GET request
      def get(path : String, params : String | Nil = nil)
        make_request(make_request_uri(path, params))
      end

      # Make a PATCH request
      def patch(path : String, body = "", params : String | Nil = nil)
        make_patch_request(make_request_uri(path, params), body)
      end

      # Make a POST request
      def post(path : String, body = "", params : String | Nil = nil)
        make_post_request(make_request_uri(path, params), body)
      end

      # Make a request with a string URI
      private def make_request(path : String, params : String | Nil = nil)
        make_request(make_request_uri(path, params))
      end

      # Make a request with a URI object
      private def make_request(uri : URI)
        self.logger.debug("GET: #{uri.to_s}", self.class.to_s)
        self.logger.debug("GET: #{default_headers}", self.class.to_s)

        resp = halite.get(uri.to_s, headers: default_headers, tls: @tls_client)
        logger.debug(resp.body, self.class.to_s)
        if resp.success?
          resp.body.empty? ? JSON.parse("{}") : resp.parse("json")
        else
          raise Error.new(resp.inspect)
        end
      rescue e : JSON::ParseException
        if (!resp.nil?)
          logger.error("Unable to parse: #{resp.body}", self.class.to_s)
        else
          logger.error(e, self.class.to_s)
        end
        raise e
      rescue e
        logger.error(e, self.class.to_s)
        raise e
      end

      private def make_post_request(uri : URI, body = "")
        self.logger.debug("POST: #{uri.to_s} BODY: #{body}", self.class.to_s)
        resp = halite.post(uri.to_s, raw: body, headers: default_headers, tls: @tls_client)
        logger.debug(resp.body, self.class.to_s)
        resp.body.empty? ? JSON.parse("{}") : resp.parse("json")
      rescue e : JSON::ParseException
        if (!resp.nil?)
          logger.error("Unable to parse: #{resp.body}", self.class.to_s)
        else
          logger.error(e, self.class.to_s)
        end
        raise e
      rescue e
        logger.error(resp.inspect)
        logger.error(e, self.class.to_s)
        raise e
      end

      private def make_patch_request(uri : URI, body = "")
        self.logger.debug("PATCH: #{uri.to_s} BODY: #{body}", self.class.to_s)
        resp = halite.patch(uri.to_s, raw: body, headers: default_headers, tls: @tls_client)
        logger.debug(resp.body, self.class.to_s)
        resp.body.empty? ? JSON.parse("{}") : resp.parse("json")
      rescue e : JSON::ParseException
        if (!resp.nil?)
          logger.error("Unable to parse: #{resp.body}", self.class.to_s)
        else
          logger.error(e, self.class.to_s)
        end
        raise e
      rescue e
        logger.error(resp.inspect)
        logger.error(e, self.class.to_s)
        raise e
      end

      private def make_delete_request(uri : URI)
        self.logger.debug("DELETE: #{uri.to_s}", self.class.to_s)
        halite.delete(uri.to_s, headers: default_headers, tls: @tls_client)
      rescue e
        logger.error(resp.inspect)
        logger.error(e, self.class.to_s)
        raise e
      end

      private def halite
        user = @user
        pass = @pass
        if !user.nil? && !pass.nil?
          Halite.basic_auth(user: user, pass: pass)
        else
          Halite::Client.new
        end
      end
    end
  end
end
