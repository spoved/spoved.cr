macro register_route(typ, path, model = nil, op_item = nil, summary = nil, schema = nil)
  Spoved::Kemal::SPOVED_ROUTES << [ {{typ}}, {{path}}, {{model ? model.stringify : ""}} ]
  %summary = {{summary}}
  %schema = {{schema}}
  %op_item = {{op_item}}

  if %op_item.nil? && %summary.is_a?(String) && %schema.is_a?(Open::Api::Schema)
    %op_item = Open::Api::OperationItem.new(%summary).tap do |op|
      op.responses["200"] = Open::Api::Response.new(%summary).tap do |resp|
        resp.content = {
          "application/json" => Open::Api::MediaType.new(schema: %schema),
        }
      end
    end
  end

  if %op_item.is_a?(Open::Api::OperationItem)
    Spoved::Kemal.open_api.add_path({{path}}, Open::Api::Operation.parse({{typ}}), %op_item)
  end
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
