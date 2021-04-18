require "./kemal/*"

macro spoved_kemal_server
  add_handler Spoved::Kemal::CorsHandler.new
  Kemal.config.logger = Spoved::Kemal::Logger.new
end
