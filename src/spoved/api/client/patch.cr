module Spoved
  class Api
    class Client
      # Make a PATCH request
      def patch(path : String, body = "", params : String | Nil = nil)
        resp = patch_raw(path, body, params)
        resp.body.empty? ? JSON.parse("{}") : resp.parse("json")
      rescue e : JSON::ParseException
        if (!resp.nil?)
          logger.error { "Unable to parse: #{resp.body}" }
        else
          logger.error { e }
        end
        raise e
      end

      # Make a PATCH request
      def patch_raw(path : String, body = "", params : String | Nil = nil)
        make_patch_request(make_request_uri(path, params), body)
      end

      private def make_patch_request(uri : URI, body = "")
        self.logger.debug { "PATCH: #{uri.to_s} BODY: #{body}" }
        resp = halite.patch(uri.to_s, raw: body, headers: default_headers, tls: tls)
        logger.debug { resp.body }
        resp
      rescue e
        logger.error { resp.inspect }
        logger.error { e }
        raise e
      end
    end
  end
end
