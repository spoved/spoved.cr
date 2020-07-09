module Spoved
  class Api
    class Client
      # Make a PUT request
      def put(path : String, body = "", params : String | Nil = nil, klass : Class = JSON::Any,
              extra_headers : Hash(String, String)? = nil)
        resp = put_raw(path, body, params, extra_headers)
        resp.body.empty? ? klass.from_json("{}") : klass.from_json(resp.body)
      rescue e : JSON::ParseException
        if (!resp.nil?)
          logger.error { "Unable to parse: #{resp.body}" }
        else
          logger.error { e }
        end
        raise e
      end

      def put_raw(path : String, body = "", params : String | Nil = nil,
                  extra_headers : Hash(String, String)? = nil)
        make_put_request(make_request_uri(path, params), body, extra_headers)
      end

      def put_file(path : String, file : File, extra_headers : Hash(String, String)? = nil)
        uri = make_request_uri(path)
        self.logger.debug { "PUT FILE: #{uri.to_s}" }

        headers = HTTP::Headers.new
        (extra_headers.nil? ? default_headers : default_headers.merge(extra_headers)).each do |k, v|
          headers[k] = v
        end

        fio = File.open(file.path)
        resp = HTTP::Client.put(url: uri.to_s, body: fio, headers: headers, tls: tls)
        fio.close

        logger.trace { resp.body }
        resp
      rescue e
        logger.error { resp.inspect }
        logger.error { e }
        raise e
      end

      def put_form(path : String, form, extra_headers : Hash(String, String)? = nil)
        uri = make_request_uri(path)
        self.logger.debug { "PUT FORM: #{uri.to_s}" }

        headers = extra_headers.nil? ? default_headers : default_headers.merge(extra_headers)
        resp = halite.put(uri.to_s, form: form, headers: headers, tls: tls)

        logger.trace { resp.body }
        resp
      rescue e
        logger.error { resp.inspect }
        logger.error { e }
        raise e
      end

      private def make_put_request(uri : URI, body = "", extra_headers : Hash(String, String)? = nil)
        self.logger.debug { "PUT: #{uri.to_s}" }
        headers = extra_headers.nil? ? default_headers : default_headers.merge(extra_headers)
        self.logger.trace { "PUT HEADERS: #{headers}" }
        self.logger.trace { "PUT BODY: #{body}" }

        resp = halite.put(uri.to_s, raw: body, headers: headers, tls: tls)

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
