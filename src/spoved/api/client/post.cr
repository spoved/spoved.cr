module Spoved
  class Api
    class Client
      # Make a POST request
      def post(path : String, body = "", params : Hash(String, String) = Hash(String, String).new, klass : Class = JSON::Any,
               extra_headers : Hash(String, String)? = nil)
        post(path, body, format_params(params), klass, extra_headers)
      end

      def post(path : String, body = "", params : String | Nil = nil, klass : Class = JSON::Any,
               extra_headers : Hash(String, String)? = nil)
        resp = post_raw(path, body, params, extra_headers)
        resp.body.empty? ? klass.from_json("{}") : klass.from_json(resp.body)
      rescue e : JSON::ParseException
        if (!resp.nil?)
          logger.error { "Unable to parse: #{resp.body}" }
        else
          logger.error { e }
        end
        raise e
      end

      def post_raw(path : String, body = "", params : String | Nil = nil,
                   extra_headers : Hash(String, String)? = nil)
        make_post_request(make_request_uri(path, params), body, extra_headers)
      end

      private def make_post_request(uri : URI, body = "", extra_headers : Hash(String, String)? = nil)
        self.logger.debug { "POST: #{uri}" }
        headers = extra_headers.nil? ? default_headers : default_headers.merge(extra_headers)

        self.logger.trace { "POST HEADERS: #{headers}" }
        self.logger.trace { "POST BODY: #{body}" }

        resp = halite.post(uri.to_s, raw: body, headers: headers, tls: tls)

        logger.trace { resp.body }
        resp
      rescue e
        logger.error { resp.inspect }
        logger.error { e }
        raise e
      end
    end
  end
end
