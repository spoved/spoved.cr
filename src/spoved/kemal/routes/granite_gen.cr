require "swagger"
require "./register"
require "../../ext/string"

macro granite_gen_routes(_model, path, filter = nil, id_class = UUID, formatter = nil, schema = nil, api_version = 1)
  {% model = _model.resolve %}
  %api_version = "v{{api_version}}"
  %model_name = _api_model_name({{model.id}})
  # %path = {{path}}
  %path = %model_name

  %open_api = Spoved::Kemal.open_api

  Log.info &.emit "Generating CRUD routes for {{model}}"
  {% primary_key = model.instance_vars.find { |var| var.annotation(Granite::Column) && var.annotation(Granite::Column)[:primary] } %}
  {% columns = [] of MetaVar %}
  {% enum_check = {} of StringLiteral => BoolLiteral %}
  {% for var in model.instance_vars %}
    {% if var.annotation(Granite::Column) %}
      {% is_enum = var.type.union_types.first < Enum %}
      {% if is_enum %}{% enum_check[var.id] = is_enum %}{% end %}
      {% if var.annotation(Granite::Column)[:primary] %}
      # skip the primary key
      {% else %}
        {% columns << var %}
      {% end %}
    {% end %}
  {% end %}

  %coll_filter_params : Array(Open::Api::Parameter) = [
    Spoved::Kemal.filter_params_for_var("{{primary_key.id}}", {{primary_key.type}}),
    {% for column in columns %}
    Spoved::Kemal.filter_params_for_var("{{column.id}}", {% if enum_check[column.id] %}String{% else %}{{column.type}}{% end %}),
    {% end %}
  ].flatten

  %coll_params = [
    {% for column in columns %}
      Open::Api::Parameter.new(
        "{{column.id}}",
        {% if enum_check[column.id] %}String{% else %}{{column.type}}{% end %},
        description: "return results that match {{column.id}}",
        default_value: {% if column.has_default_value? %}{{column.default_value.id}}{% if enum_check[column.id] %}.to_s{% end %}{% else %}nil{% end %}
      ),
    {% end %}
  ] of Open::Api::Parameter

  %object_name = _api_model_name({{_model}})
  register_schema({{model}})
  %resp_list_object_name, %resp_list_object = Spoved::Kemal.create_list_schemas(%object_name)
  %open_api.register_schema(%resp_list_object_name, %resp_list_object)

  ###### GET List ######

  %get_list_path = "/api/#{%api_version}/#{%path}"
  %open_api.add_path(%get_list_path, Open::Api::Operation::Get,
    item: Spoved::Kemal.create_get_list_op_item(
      model_name: %model_name,
      params: Spoved::Kemal.list_req_params + %coll_filter_params,
      resp_ref: %open_api.schema_ref(%resp_list_object_name)
    )
  )

  register_route("GET", %get_list_path, {{model.id}})
  get %get_list_path do |env|
    env.response.content_type = "application/json"
    limit, offset = Spoved::Kemal.limit_offset_args(env)
    sort_by, sort_order = Spoved::Kemal.sort_args(env)
    filters = Spoved::Kemal.param_args(env, %coll_filter_params)

    Log.notice &.emit "get {{model.id}}", filters: filters.to_json, limit: limit,
      offset: offset, sort_by: sort_by, sort_order: sort_order

    query = {{model.id}}.where

    # If sort is not specified, sort by provided column
    sort_by.each do |v|
      case v
      when "{{primary_key.id}}"
        query.order({{primary_key.id}}: sort_order == "desc" ? :desc : :asc)
      {% for column in columns %}
      when "{{column.id}}"
        query.order({{column.id}}: sort_order == "desc" ? :desc : :asc)
      {% end %}
      end
    end

    # If filters are specified, apply them
    filters.each do |filter|
      query.where(filter[:name], filter[:op], filter[:value])
    end

    total = query.size.run
    query.offset(offset) if offset > 0
    query.limit(limit) if limit > 0
    items = query.select
    resp = { limit:  limit, offset: offset, size:   items.size, total:  total, items:  items }
    Spoved::Kemal.set_content_length(resp.to_json, env)
  rescue ex
    Log.error(exception: ex) {ex.message}
    Spoved::Kemal.resp_400(env, ex.message)
  end

  ###### GET By Id ######
  %path_id_param = Open::Api::Parameter.new(
    "{{primary_key.id}}",
    {{primary_key.type}},
    location: "path",
    description: "id of record", required: true
  )
  %open_api.add_path("/api/#{%api_version}/#{%path}/{{{primary_key.id}}}", Open::Api::Operation::Get,
    item: Spoved::Kemal.create_get_op_item(
      model_name: %model_name,
      params: [
        %path_id_param
      ],
      resp_ref: %open_api.schema_ref(%object_name)
    )
  )

  register_route("GET", "/api/#{%api_version}/#{%path}/:{{primary_key.id}}", {{model.id}})
  get "/api/#{%api_version}/#{%path}/:{{primary_key.id}}" do |env|
    env.response.content_type = "application/json"
    id = env.params.url["{{primary_key.id}}"]
    Log.notice &.emit "get {{model.id}}", id: id
    item = {{model.id}}.find({{id_class}}.new(id))
    if item.nil?
      Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
    else
      Spoved::Kemal.set_content_length(item.to_json, env)
    end
  rescue ex
    Log.error(exception: ex) {ex.message}
    Spoved::Kemal.resp_400(env, ex.message)
  end

  ###### DELETE By Id ######
  register_route("DELETE", "/api/#{%api_version}/#{%path}/:{{primary_key.id}}", {{model.id}})
  %open_api.add_path("/api/#{%api_version}/#{%path}/{{{primary_key.id}}}", Open::Api::Operation::Delete,
    item: Spoved::Kemal.create_delete_op_item(
      model_name: %model_name,
      params: [
        %path_id_param
      ],
    )
  )

  delete "/api/#{%api_version}/#{%path}/{{{primary_key.id}}}" do |env|
    env.response.content_type = "application/json"
    env.response.content_type = "application/json"
    id = env.params.url["{{primary_key.id}}"]
    Log.notice &.emit "delete {{model.id}}", id: id
    item = {{model.id}}.find({{id_class}}.new(id))
    if item.nil?
      Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
    else
      item.destroy!
      Spoved::Kemal.resp_204(env)
    end
  rescue ex
    Log.error(exception: ex) {ex.message}
    Spoved::Kemal.resp_400(env, ex.message)
  end


  ###### POST/PUT ######
  register_route("PUT", "/api/#{%api_version}/#{%path}", {{model.id}})
  %open_api.add_path("/api/#{%api_version}/#{%path}", Open::Api::Operation::Put,
    item: Spoved::Kemal.create_put_op_item(
      model_name: %model_name,
      model_ref: %open_api.schema_ref(%object_name),
      body_schema: Spoved::Kemal.body_schema({{model.id}}),
    )
  )

  put "/api/#{%api_version}/#{%path}" do |env|
    env.response.content_type = "application/json"
    item = {{model}}.from_json(env.request.body.not_nil!)
    item.save!
    Spoved::Kemal.set_content_length(item.to_json, env)
  rescue ex
    Log.error(exception: ex) {ex.message}
    Spoved::Kemal.resp_400(env, ex.message)
  end

  ###### PATCH ######
  %patch_body_params = [
    {% for column in columns %}
    {% if column.id != "created_at" && column.id != "modified_at" %}
      Open::Api::Parameter.new(
        "{{column.id}}",
        {% if enum_check[column.id] %}String{% else %}{{column.type}}{% end %},
        description: "update the value of {{column.id}}",
        location: "body"
      ),
    {% end %}
    {% end %}
  ]

  %patch_body_object = Open::Api::Schema.new(
    schema_type: "object",
    required: [
      {% for column in columns %}
        {% if column.id != "created_at" && column.id != "modified_at" && !column.has_default_value? %}
          "{{column.id}}",
        {% end %}
      {% end %}
    ] of String,
    properties: Hash(String, Open::Api::SchemaRef){
      {{primary_key.id.stringify}} => Open::Api::Schema.new(
        {% if enum_check[primary_key.id] %}
        schema_type: "string", format: "string", default: {{primary_key.default_value.id}}.to_s,
        {% else %}
        schema_type: Open::Api.get_open_api_type({{primary_key.type}}),
        format: Open::Api.get_open_api_format({{primary_key.type}}),
        default: {{primary_key.default_value.id}}
        {% end %}
      ),
      {% for column in columns %}
      {% if column.id != "created_at" && column.id != "modified_at" %}
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
      {% end %}
    }
  )

  register_route("PATCH", "/api/#{%api_version}/#{%path}/:{{primary_key.id}}", {{model.id}})
  %open_api.add_path("/api/#{%api_version}/#{%path}/{{{primary_key.id}}}", Open::Api::Operation::Patch,
    item: Spoved::Kemal.create_patch_op_item(
      model_name: %model_name,
      params: [
        %path_id_param
      ],
      body_object: %patch_body_object,
      model_ref: %open_api.schema_ref(%object_name)
    )
  )

  patch "/api/#{%api_version}/#{%path}/{{{primary_key.id}}}" do |env|
    env.response.content_type = "application/json"
    id = env.params.url["{{primary_key.id}}"]
    Log.notice &.emit "patch {{model.id}}", id: id
    item = {{model.id}}.find({{id_class}}.new(id))
    if item.nil?
      Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
    else
      values = Spoved::Kemal.param_args(env, %patch_body_params)
      values.each do |param|
        case param[:name]
        {% for column in columns %}
        when "{{column.id}}"
          {% if enum_check[column.id] %}
          item.{{column.id}} =  {{column.type.union_types.first}}.parse(param[:value].as(String))
          {% elsif column.type.union_types.first <= UUID %}
          item.{{column.id}} = UUID.new(param[:value].as(String))
          {% elsif column.type.union_types.first <= Int32 %}
          %var = param[:value].as(Int64)
          item.{{column.id}} = %var.to_i unless %var.nil?
          {% else %}
          %var = param[:value].as({{column.type}})
          item.{{column.id}} = %var unless %var.nil?
          {% end %}
        {% end %}
        end
      end
      item.save!
      Spoved::Kemal.set_content_length(item.to_json, env)
    end
  rescue ex
    Log.error(exception: ex) {ex.message}
    Spoved::Kemal.resp_400(env, ex.message)
  end

  Log.info { "Generating relationship routes for {{model.id}}" }
  # Relationships
  {% for meth in model.methods %}
    {% if meth.annotation(Granite::Relationship) %}
      {% anno = meth.annotation(Granite::Relationship) %}
      %target_object_name = _api_model_name({{anno[:target]}})
      register_schema({{anno[:target]}})
      Log.debug {"registering relationship: #{%model_name} -> #{%target_object_name}, type: {{anno[:type]}}"}

      {% if anno[:type] == :has_one || anno[:type] == :belongs_to %}
        %_path_ = "/api/#{%api_version}/#{%path}/{{{primary_key.id}}}/#{%target_object_name}"
        %open_api.add_path(%_path_, Open::Api::Operation::Get,
          item: Spoved::Kemal.create_get_op_item(
            operation_id: "get_#{%model_name}_#{%target_object_name}",
            model_name: %model_name,
            params: [
              %path_id_param
            ],
            resp_ref: %open_api.schema_ref(%target_object_name)
          )
        )
        %_kemal_path = "/api/#{%api_version}/#{%path}/:{{primary_key.id}}/#{%target_object_name}"
        register_route("GET", %_kemal_path, {{model.id}})
        get %_kemal_path do |env|
          env.response.content_type = "application/json"
          id = env.params.url["{{primary_key.id}}"]
          item = {{model.id}}.find({{id_class}}.new(id))
          if item.nil?
            Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
          else
            Spoved::Kemal.set_content_length(item.{{meth.name}}.to_json, env)
          end
        rescue ex
          Log.error(exception: ex) {ex.message}
          Spoved::Kemal.resp_400(env, ex.message)
        end

      {% elsif anno[:type] == :has_many %}
        %_path_ = "/api/#{%api_version}/#{%path}/{{{primary_key.id}}}/#{%target_object_name.pluralize}"
        %open_api.add_path(%_path_, Open::Api::Operation::Get,
          item: Spoved::Kemal.create_get_list_op_item(
            operation_id: "get_#{%model_name}_#{%target_object_name}_list",
            model_name: %model_name,
            params: [
              Spoved::Kemal.list_req_params,
              %path_id_param,
            ].flatten,
            resp_ref: %open_api.schema_ref(%resp_list_object_name)
          )
        )

        %_kemal_path = "/api/#{%api_version}/#{%path}/:{{primary_key.id}}/#{%target_object_name.pluralize}"
        register_route("GET", %_kemal_path, {{model.id}})
        get %_kemal_path do |env|
          env.response.content_type = "application/json"
          limit, offset = Spoved::Kemal.limit_offset_args(env)
          sort_by, sort_order = Spoved::Kemal.sort_args(env)
          id = env.params.url["{{primary_key.id}}"]
          query = {{anno[:target]}}.where({{anno[:foreign_key].id}}: {{id_class}}.new(id))
          # If sort is not specified, sort by provided column
          sort_by.each do |v|
            case v
            when "{{primary_key.id}}"
              query.order({{primary_key.id}}: sort_order == "desc" ? :desc : :asc)
            {% for column in columns %}
            when "{{column.id}}"
              query.order({{column.id}}: sort_order == "desc" ? :desc : :asc)
            {% end %}
            end
          end

          total = query.size.run
          query.offset(offset) if offset > 0
          query.limit(limit) if limit > 0
          items = query.select
          resp = { limit:  limit, offset: offset, size:   items.size, total:  total, items:  items }
          Spoved::Kemal.set_content_length(resp.to_json, env)
        rescue ex
          Log.error(exception: ex) {ex.message}
          Spoved::Kemal.resp_400(env, ex.message)
        end
      {% end %}
    {% end %}
  {% end %}
end
