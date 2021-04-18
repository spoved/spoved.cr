require "open-api"

module Spoved::Kemal
  SPOVED_ROUTES = Array(Array(String)).new
end

macro register_route(typ, path, model = nil, filter = nil, multi = false, schema = nil)
  Spoved::Kemal::SPOVED_ROUTES << [ {{typ}}, {{path}}, {{model ? model.stringify : ""}} ]

  %path = {{path}}.gsub(/\:id/, "{id}")
  Log.debug { "Registering route {{model.id}} => {{typ.id}} : #{%path}" }

  {% if model %}
    register_schema({{model.id}})
  {% end %}
  {% opr = typ.downcase %}

  Open::Api.route_meta[%path] = Hash(String, Open::Api::RouteMetaDatum).new unless Open::Api.route_meta[%path]?
  Open::Api.route_meta[%path][{{opr}}] = Open::Api::RouteMetaDatum{
            :model => {{model.stringify}},
            :opr => {{typ}},
            :path => %path,
            :filter => {% if filter %} {{filter}}.to_h {% else %} Hash(Symbol, String).new {% end %},
            :multi => {{multi}},
            :schema => {% if schema %} {{schema}} {% else %} nil {% end %},
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

    {{model.id}}.attr_types.each do |k, v|
      %required << k.to_s
      case v
      when UUID.class, BSON::ObjectId.class, String.class, .is_a?(Enum.class)
        %props[k.to_s] = Open::Api::Schema.new("string")
      when Int32.class
        %props[k.to_s] = Open::Api::Schema.new("integer", format: "int32")
      when Int64.class
        %props[k.to_s] = Open::Api::Schema.new("integer", format: "int64")
      when Bool.class
        %props[k.to_s] = Open::Api::Schema.new("boolean")
      when Hash(String, String).class
        %props[k.to_s] = Open::Api::Schema.new("object")
      when .is_a?(Array.class)
        %props[k.to_s] = Open::Api::Schema.new("array", items: Open::Api::Schema.new("object"))
      when Float32.class, Float64.class
        %props[k.to_s] = Open::Api::Schema.new("number", format: "float")
      when .is_a?(Hash.class)
        %props[k.to_s] = Open::Api::Schema.new("object")
      when .is_a?(Time.class)
        %props[k.to_s] = Open::Api::Schema.new("string", format: "date-time")
      else
        raise "Unable to parse open api type for #{v}"
      end
    end
    Open::Api.schema_refs[{{model.stringify}}] = Open::Api::Schema.new(
        "object",
        required: %required,
        properties: %props
      )
  end
end

def print_routes
  resources = Spoved::SPOVED_ROUTES.map(&.last).uniq!.sort
  resources.each do |resource|
    puts resource

    data = Spoved::SPOVED_ROUTES.select(&.last.==(resource))
    table = Tablo::Table.new(data, connectors: Tablo::CONNECTORS_SINGLE_DOUBLE) do |t|
      t.add_column("Path", &.[0])
      t.add_column("Path", &.[1])
    end

    table.shrinkwrap!
    puts table
    puts ""
  end
end
