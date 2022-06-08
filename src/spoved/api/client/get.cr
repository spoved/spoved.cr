module Spoved
  class Api
    class Client
      # Make a GET request
      def get(path : String, params = Hash(String, String).new, klass : Class = JSON::Any)
        get(path, format_params(params), klass)
      end

      def stream_get(path : String, params = Hash(String, String).new)
        halite.get(make_request_uri(path, format_params(params)).to_s,
          headers: default_headers, tls: tls) do |response|
          spawn do
            logger.warn { "Spawn #{stream} start" }
            while !stream.closed?
              response.body_io.each_line do |line|
                stream.send(line)
              end
            end
            logger.warn { "Spawn #{stream} end" }
          end
        end
      end

      # Make a GET request
      def get(path : String, params : String | Nil = nil, klass : Class = JSON::Any,
              extra_headers : Hash(String, String)? = nil)
        resp = get_raw(path, params, extra_headers)

        if resp.success?
          resp.body.empty? ? klass.from_json("{}") : klass.from_json(resp.body)
        else
          raise Error.new(resp.inspect)
        end
      rescue e : JSON::ParseException
        if (!resp.nil?)
          logger.error { "Unable to parse: #{resp.body}" }
        else
          logger.error { e }
        end
        raise e
      end

      def get_raw(path : String, params : String | Nil = nil, extra_headers : Hash(String, String)? = nil)
        make_request(make_request_uri(path, params), extra_headers)
      end

      # Make a request with a string URI
      private def make_request(path : String, params : String? = nil, extra_headers : Hash(String, String)? = nil)
        make_request(make_request_uri(path, params), extra_headers)
      end

      # Make a request with a URI object
      private def make_request(uri : URI, extra_headers : Hash(String, String)? = nil)
        self.logger.debug { "GET: #{uri}" }
        headers = extra_headers.nil? ? default_headers : default_headers.merge(extra_headers)
        self.logger.trace { "GET HEADERS: #{headers}" }
        resp = halite.get(uri.to_s, headers: headers, tls: tls)
        logger.trace { resp.body }
        resp
      rescue e
        logger.error { e }
        raise e
      end
    end
  end
end
