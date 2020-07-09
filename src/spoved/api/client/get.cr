module Spoved
  class Api
    class Client
      # Make a GET request
      def get(path : String, params : Hash(String, String), klass : Class = JSON::Any)
        get(path, format_params(params), klass)
      end

      def stream_get(path : String, params : Hash(String, String))
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
      def get(path : String, params : String | Nil = nil, klass : Class = JSON::Any)
        resp = get_raw(path, params)
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

      def get_raw(path : String, params : String | Nil = nil)
        make_request(make_request_uri(path, params))
      end
    end
  end
end
