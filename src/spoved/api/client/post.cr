module Spoved
  class Api
    class Client
      # Make a POST request
      def post(path : String, body = "", params : String | Nil = nil, klass : Class = JSON::Any)
        resp = post_raw(path, body, params)
        resp.body.empty? ? klass.from_json("{}") : klass.from_json(resp.body)
      rescue e : JSON::ParseException
        if (!resp.nil?)
          logger.error { "Unable to parse: #{resp.body}" }
        else
          logger.error { e }
        end
        raise e
      end

      def post_raw(path : String, body = "", params : String | Nil = nil)
        make_post_request(make_request_uri(path, params), body)
      end

      private def make_post_request(uri : URI, body = "", extra_headers : Hash(String, String)? = nil)
        self.logger.debug { "POST: #{uri.to_s} BODY: #{body}" }
        headers = extra_headers.nil? ? default_headers : default_headers.merge(extra_headers)

        resp = halite.post(uri.to_s, raw: body, headers: headers, tls: tls)
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
