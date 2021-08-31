module Spoved::Kemal
  macro body_schema(_model)
    Open::Api::Schema.new("object").tap do |schema|
      {% model = _model.resolve %}
      {% columns = [] of MetaVar %}
      {% enum_check = {} of StringLiteral => BoolLiteral %}
      {% for var in model.instance_vars %}
        {% if var.annotation(Granite::Column) %}
          {% enum_check[var.id] = var.type.union_types.first < Enum %}
          {% if var.annotation(Granite::Column)[:primary] %}
            # skip the primary key
          {% elsif var.id == :created_at || var.id == :modified_at %}
          {% else %}
            {% columns << var %}
          {% end %}
        {% end %}
      {% end %}
      schema.properties = Hash(String, Open::Api::SchemaRef){
        {% for column in columns %}
        {{column.id.stringify}} => Open::Api::Schema.new(
          {% if enum_check[column.id] %}
          schema_type: "string", format: "string", default: {{column.default_value.id}}.to_s,
          {% else %}
          schema_type: Open::Api.get_open_api_type({{column.type}}),
          format: Open::Api.get_open_api_format({{column.type}}),
          default: {{column.default_value.id}}
          {% end %}
        ),
        {% end %}
      }
    end
  end
end

macro register_route(typ, path, model = nil, op_item = nil, summary = nil, schema = nil)
  Log.debug { "registring route: " + {{path}} }
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

macro _api_model_name(model)
  {{model.id.stringify.split("::").last.gsub(/:+/, "_").underscore}}
end

macro register_schema(_model)
  {% model = _model.resolve %}

  %object_name = _api_model_name({{_model}})
  %open_api = Spoved::Kemal.open_api

  if !%open_api.has_schema_ref?(%object_name)
    Log.info { "Register schema {{model.id}}" }

    {% primary_key = model.instance_vars.find { |var| var.annotation(Granite::Column) && var.annotation(Granite::Column)[:primary] } %}
    {% columns = [] of MetaVar %}
    {% enum_check = {} of StringLiteral => BoolLiteral %}
    {% for var in model.instance_vars %}
      {% if var.annotation(Granite::Column) %}
        {% enum_check[var.id] = var.type.union_types.first < Enum %}
        {% columns << var %}
      {% end %}
    {% end %}

    %object = Open::Api::Schema.new(
      schema_type: "object",
      required: [
        {{primary_key.id.stringify}},
      ],
      properties: Hash(String, Open::Api::SchemaRef){
        {% for column in columns %}
        {{column.id.stringify}} => Open::Api::Schema.new(
          {% if enum_check[column.id] %}
          schema_type: "string", format: "string", default: {{column.default_value.id}}.to_s,
          {% else %}
          schema_type: Open::Api.get_open_api_type({{column.type}}),
          format: Open::Api.get_open_api_format({{column.type}}),
          default: {{column.default_value.id}}
          {% end %}
        ),
        {% end %}
      }
    )

    %open_api.register_schema(%object_name, %object)
  end
end
