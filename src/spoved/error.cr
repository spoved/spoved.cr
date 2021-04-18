require "../spoved"

module Spoved
  class Error < Exception
  end

  class Api
    class Error < Spoved::Error
    end

    class Client
      class Error < Spoved::Api::Error
      end
    end
  end

  class Config
    class Error < Spoved::Error
    end

    class KeyError < Spoved::Config::Error
    end
  end
end
