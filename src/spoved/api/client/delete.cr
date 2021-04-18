module Spoved
  class Api
    class Client
      # Make a DELETE request
      def delete(path : String, params : String | Nil = nil, extra_headers : Hash(String, String)? = nil)
        make_delete_request(make_request_uri(path, params), extra_headers)
      end

      private def make_delete_request(uri : URI, extra_headers : Hash(String, String)? = nil)
        self.logger.debug { "DELETE: #{uri}" }
        headers = extra_headers.nil? ? default_headers : default_headers.merge(extra_headers)
        self.logger.trace { "DELETE HEADERS: #{headers}" }

        halite.delete(uri.to_s, headers: headers, tls: tls)
      rescue e
        logger.error { e }
        raise e
      end
    end
  end
end
