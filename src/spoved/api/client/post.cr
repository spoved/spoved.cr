module Spoved
  class Api
    class Client
      # Make a POST request
      def post(path : String, body = "", params : String | Nil = nil)
        make_post_request(make_request_uri(path, params), body)
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
    end
  end
end
