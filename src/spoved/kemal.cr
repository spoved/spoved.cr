require "../spoved"
require "./kemal/*"

macro spoved_kemal_server
  register_route("OPTIONS", "/*", nil,
    schema: Open::Api::Schema.new("object",
      required: ["msg"],
      properties: Hash(String, Open::Api::SchemaRef){"msg" => Open::Api::Schema.new("string")})
  )
  options "/*" do
    # TODO: what should OPTIONS requests actually respond with?
    {msg: "ok"}.to_json
  end

  add_handler Spoved::Kemal::CorsHandler.new
  Kemal.config.logger = Spoved::Kemal::Logger.new
end
