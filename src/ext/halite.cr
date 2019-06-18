module Halite
  module Chainable
    def basic_auth(user : String, pass : String) : Halite::Client
      auth("Basic " + Base64.strict_encode(user + ":" + pass).chomp)
    end
  end
end
