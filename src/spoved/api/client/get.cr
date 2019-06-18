module Spoved
  class Api
    class Client
      # Make a GET request
      def get(path : String, params : Hash(String, String))
        get(path, format_params(params))
      end

      def stream_get(path : String, params : Hash(String, String))
        halite.get(make_request_uri(path, format_params(params)).to_s,
          headers: default_headers, tls: tls) do |response|
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

      # Make a GET request
      def get(path : String, params : String | Nil = nil)
        make_request(make_request_uri(path, params))
      end
    end
  end
end
