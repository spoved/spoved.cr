module Spoved
  class Api
    class Client
      # Make a DELETE request
      def delete(path : String, params : String | Nil = nil)
        make_delete_request(make_request_uri(path, params))
      end

      private def make_delete_request(uri : URI)
        self.logger.debug { "DELETE: #{uri.to_s}" }
        halite.delete(uri.to_s, headers: default_headers, tls: tls)
      rescue e
        logger.error { e }
        raise e
      end
    end
  end
end
