require "swagger/http/handler"

module Spoved::Kemal
  extend self

  def not_found_resp(env, msg)
    env.response.status_code = 404
    env.response.content_type = "application/json"
    env.response.print(set_content_length({code: 404, message: msg}.to_json, env))
    env.response.close
  end

  def resp_204(env)
    env.response.status_code = 204
    env.response.close
  end

  macro resp_400(env, msg)
    {{env}}.response.status_code = 400
    {{env}}.response.content_type = "application/json"
    halt {{env}}, status_code: 400, response: ({code: 400, message: {{msg}}}.to_json)
  end

  def set_content_length(resp, env)
    resp = "{}" if resp.nil?
    env.response.content_length = resp.bytesize
    resp
  end

  def response_data(limit, offset, data, total)
    {
      limit:  limit,
      offset: offset,
      size:   data.size,
      total:  total,
      data:   data,
    }
  end

  def limit_offset_args(env)
    limit = env.params.query["limit"]?.nil? ? DEFAULT_LIMIT : env.params.query["limit"].to_i
    offset = env.params.query["offset"]?.nil? ? 0 : env.params.query["offset"].to_i

    {limit, offset}
  end

  def sort_args(env)
    sort_by = env.params.query["sort_by"]?.nil? ? Array(String).new : env.params.query["sort_by"].split(",")
    sort_order = env.params.query["sort_order"]?.nil? ? "asc" : env.params.query["sort_order"]
    {sort_by, sort_order}
  end

  def order_by_args(env)
    order_by = env.params.query["order_by"]?.nil? ? nil : env.params.query["order_by"]
    if order_by.nil?
      Array(String).new
    else
      order_by.split(',')
    end
  end

  private def string_to_operator(str)
    {% begin %}
    case str
    {% for op in [:eq, :gteq, :lteq, :neq, :gt, :lt, :nlt, :ngt, :ltgt, :in, :nin, :like, :nlike] %}
    when "{{op.id}}", "{{op}}", {{op}}
      {{op}}
    {% end %}
    else
      raise "unknown filter operator #{str}"
    end
    {% end %}
  end

  alias ParamFilter = NamedTuple(name: String, op: Symbol, value: Bool | Float64 | Int64 | String | Array(String))

  def param_args(env, filter_params : Array(Open::Api::Parameter)) : Array(ParamFilter)
    result = Array(ParamFilter).new

    filter_params.each do |param|
      val = param_filter(param, env)
      unless val.nil?
        result << val
      end
    end
    result
  end

  # Fetch the value from the http request
  private def param_value(param : Open::Api::Parameter, env)
    case param.parameter_in
    when "query"
      env.params.query[param.name]?.nil? ? nil : env.params.query[param.name]
    when "path"
      env.params.url[param.name]?.nil? ? nil : env.params.url[param.name]
    when "header"
      env.response.headers[param.name]?.nil? ? nil : env.response.headers[param.name]
    when "body"
      if env.response.headers["Content-Type"] == "application/json"
        env.params.json[param.name]?.nil? ? nil : env.params.json[param.name]
      else
        env.params.body[param.name]?.nil? ? nil : env.params.body[param.name].as(String)
      end
    else
      nil
    end
  end

  # Convert the `Open::Api::Parameter` to a filter struct
  private def param_filter(param : Open::Api::Parameter, env) : ParamFilter?
    param_name = param.name
    op = :eq
    param_value = param_value(param, env)
    return nil if param_value.nil?

    if param_name =~ /^(.*)_(:\w+)$/
      param_name = $1
      op = string_to_operator($2)
    end

    case param_value
    when String
      if op == :in || op == :nin
        param_value = param_value.split(',')
      elsif op == :like || op == :nlike
        param_value = "%#{param_value}%"
      end
      {name: param_name, op: op, value: param_value}
    when Bool, Float64, Int64
      {name: param_name, op: op, value: param_value}
    else
      nil
    end
  end

  # Create a schema object for a list return
  def create_list_schemas(ref_name)
    items_schema = Open::Api::Schema.new(
      schema_type: "array",
      items: Open::Api::Ref.new("#/components/schemas/#{ref_name}")
    )

    resp_list_object_name = "#{ref_name}_resp_list"
    resp_list_object = Open::Api::Schema.new(
      schema_type: "object",
      required: [
        "limit",
        "offset",
        "size",
        "total",
        "items",
      ],
      properties: Hash(String, Open::Api::SchemaRef){
        "limit"  => Open::Api::Schema.new("integer", default: 0),
        "offset" => Open::Api::Schema.new("integer", default: 0),
        "size"   => Open::Api::Schema.new("integer", default: 0),
        "total"  => Open::Api::Schema.new("integer", default: 0),
        "items"  => items_schema,
      },
      example: Hash(String, Open::Api::ExampleValue){
        "limit"  => 0,
        "offset" => 0,
        "size"   => 0,
        "total"  => 0,
        "items"  => Array(Open::Api::ExampleValue).new,
      }
    )

    {resp_list_object_name, resp_list_object}
  end

  def create_patch_body_schemas(model_def) : Open::Api::Schema
    params = model_def.body_params
    properties = model_def.properties.select { |k, v| k != "created_at" && k != "created_at" && k != model_def.primary_key }

    Open::Api::Schema.new(
      schema_type: "object",
      required: params.select(&.required).map(&.name),
      properties: properties,
    )
  end
end
