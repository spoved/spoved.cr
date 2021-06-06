require "open-api"
require "tablo"

module Spoved::Kemal
  SPOVED_ROUTES = Array(Array(String)).new
end

macro register_route(typ, path, model = nil, filter = nil, multi = false, schema = nil, summary = nil, description = nil, tags = nil)
  Spoved::Kemal::SPOVED_ROUTES << [ {{typ}}, {{path}}, {{model ? model.stringify : ""}} ]

  %path = {{path}}.gsub(/\:id/, "{id}")
  Log.debug { "Registering route {{model.id}} => {{typ.id}} : #{%path}" }

  {% if model %}
    register_schema({{model.id}})
  {% end %}
  {% opr = typ.downcase %}

  Open::Api.route_meta[%path] = Hash(String, Open::Api::RouteMetaDatum).new unless Open::Api.route_meta[%path]?
  Open::Api.route_meta[%path][{{opr}}] = Open::Api::RouteMetaDatum{
            :model => {% if model %} {{model.stringify}} {% else %} nil {% end %} ,
            :opr => {{typ}},
            :path => %path,
            :filter => {% if filter %} {{filter}}.to_h {% else %} Hash(Symbol, String).new {% end %},
            :multi => {{multi}},
            :schema => {% if schema %} {{schema}} {% else %} nil {% end %},
            :summary => {{summary}},
            :description => {{description}},
            :tags => {% if tags %} {{tags}} {% else %} Array(String).new {% end %},
          {% if multi %}
            :wrapper => {
             method: ->(){
              Open::Api::Schema.new(
                  schema_type: "object",
                  required: [
                    "limit",
                    "offset",
                    "size",
                    "total",
                    "data",
                  ],
                  properties: Hash(String, Open::Api::SchemaRef){
                    "limit"  => Open::Api::Schema.new("integer", default: 0),
                    "offset" => Open::Api::Schema.new("integer", default: 0),
                    "size"   => Open::Api::Schema.new("integer", default: 0),
                    "total"  => Open::Api::Schema.new("integer", default: 0),
                  },
                  example: Hash(String, Open::Api::ExampleValue){
                    "limit"  => 0,
                    "offset" => 0,
                    "size"   => 0,
                    "total"  => 0,
                    "data" => Array(Open::Api::ExampleValue).new
                  }
                )
              },
              key: "data"
            }
          {% end %}
  }
end

macro register_schema(model)
  Log.info { "Register schema {{model.id}}" }
  # Log.warn { Open::Api.schema_refs.keys }
  unless Open::Api.schema_refs[{{model.stringify}}]?
    Log.notice { "Generating schema {{model.id}}" }

    %props = Hash(String, Open::Api::SchemaRef).new
    %required = Array(String).new
    %example = Hash(String, Open::Api::ExampleValue).new

    {{model.id}}.attr_types.each do |k, v|
      %required << k.to_s
      case v
      when UUID.class, BSON::ObjectId.class, String.class, .is_a?(Enum.class)
        %props[k.to_s] = Open::Api::Schema.new("string")
        %example[k.to_s] = "string"
      when Int32.class
        %props[k.to_s] = Open::Api::Schema.new("integer", format: "int32", example: 0_i32)
        %example[k.to_s] = 0_i32
      when Int64.class
        %props[k.to_s] = Open::Api::Schema.new("integer", format: "int64", example: 0_i64)
        %example[k.to_s] = 0_i64
      when Bool.class
        %props[k.to_s] = Open::Api::Schema.new("boolean", example: false)
        %example[k.to_s] = false
      when .is_a?(Array.class)
        %props[k.to_s] = Open::Api::Schema.new("array", items: Open::Api::Schema.new("object"))
        %example[k.to_s] = Array(Open::Api::ExampleValue).new
      when Float32.class, Float64.class
        %props[k.to_s] = Open::Api::Schema.new("number", format: "float", example: 0.0_f32)
        %example[k.to_s] = 0_f32
      when .is_a?(Hash.class), Struct.class
        %props[k.to_s] = Open::Api::Schema.new("object")
        %example[k.to_s] = Hash(String, Open::Api::ExampleValue).new
      when .is_a?(Time.class)
        %props[k.to_s] = Open::Api::Schema.new("string", format: "date-time", example: Time.utc.to_rfc3339)
        %example[k.to_s] = Time.utc.to_rfc3339
      else
        raise "Unable to parse open api type for #{v}"
      end
    end
    Open::Api.schema_refs[{{model.stringify}}] = Open::Api::Schema.new(
        "object",
        required: %required,
        properties: %props,
        example: %example,
      )
  end
end

def print_routes
  resources = Spoved::Kemal::SPOVED_ROUTES.map(&.last).uniq!.sort
  resources.each do |resource|
    puts resource

    data = Spoved::Kemal::SPOVED_ROUTES.select(&.last.==(resource))
    table = Tablo::Table.new(data, connectors: Tablo::CONNECTORS_SINGLE_DOUBLE) do |t|
      t.add_column("Path", &.[0])
      t.add_column("Path", &.[1])
    end

    table.shrinkwrap!
    puts table
    puts ""
  end
end
