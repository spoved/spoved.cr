require "http/client"
require "json"

class HTTP::Client
  def get(url : String, headers = nil, params = nil)
    return super if headers.nil? && params.nil?

    _params = params.nil? ? URI::Params.new : URI::Params.encode(params)

    if headers
      h = HTTP::Headers.new
      headers.each do |k, v|
        h.add k.to_s, v
      end
      self.get "#{url}?#{_params}", headers: h
    else
      self.get "#{url}?#{_params}"
    end
  end
end

class HTTP::Client::Response
  def parse
    if self.success? && self.body?
      JSON.parse(self.body)
    else
      raise "Unable to parse body for response. status_code: #{status_code}"
    end
  rescue ex
    puts self.body
    raise ex
  end
end
