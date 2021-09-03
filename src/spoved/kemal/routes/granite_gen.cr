require "swagger"
require "./register"
require "../../ext/string"
require "./model_def"

macro granite_gen_routes(_model, path = nil, filter = nil, id_class = UUID, formatter = nil, schema = nil, api_version = 1)
  {% model = _model.resolve %}
  %api_version = "v{{api_version}}"
  %model_name = Spoved::Kemal._api_model_name({{model.id}})
  %path : String = {{path}}.nil? ? %model_name : {{path}}.not_nil!
  %open_api = Spoved::Kemal.open_api

  Log.info &.emit "Generating CRUD routes for {{model}}"
  %model_def : Spoved::Kemal::ModelDef({{model.id}}) = Spoved::Kemal::ModelDef({{model.id}}).new(%model_name, %path)
  # Spoved::Kemal.populate_model_def({{_model}}, %model_def)

  Spoved::Kemal.register_schema({{model}}, %model_def)
  %resp_list_object_name, %resp_list_object = Spoved::Kemal.create_list_schemas(%model_def.name)
  %open_api.register_schema(%resp_list_object_name, %resp_list_object) unless %open_api.has_schema_ref?(%resp_list_object_name)
  %patch_body_params = %model_def.body_params
  %patch_body_object = Spoved::Kemal.create_patch_body_schemas(%model_def)

  ###### GET List ######

  %get_list_path = "/api/#{%api_version}/#{%path}"
  %open_api.add_path(%get_list_path, Open::Api::Operation::Get,
    item: Spoved::Kemal.create_get_list_op_item(
      model_name: %model_def.name,
      params: Spoved::Kemal.list_req_params + %model_def.coll_filter_params,
      resp_ref: %open_api.schema_ref(%resp_list_object_name)
    )
  )

  Spoved::Kemal.register_route("GET", %get_list_path, {{model.id}})
  get %get_list_path do |env|
    env.response.content_type = "application/json"
    limit, offset = Spoved::Kemal.limit_offset_args(env)
    sort_by, sort_order = Spoved::Kemal.sort_args(env)
    filters = Spoved::Kemal.param_args(env, %model_def.coll_filter_params)

    Log.notice &.emit "get {{model.id}}", filters: filters.to_json, limit: limit,
      offset: offset, sort_by: sort_by, sort_order: sort_order

    query = {{model.id}}.where

    # If sort is not specified, sort by provided column
    %model_def.sort_by.call(sort_by, sort_order, query)

    # If filters are specified, apply them
    %model_def.apply_filters.call(filters, query)

    total = query.size.run
    query.offset(offset) if offset > 0
    query.limit(limit) if limit > 0
    items = query.select
    resp = { limit:  limit, offset: offset, size: items.size, total:  total, items:  items }
    Spoved::Kemal.set_content_length(resp.to_json, env)
  rescue ex
    Log.error(exception: ex) {ex.message}
    Spoved::Kemal.resp_400(env, ex.message)
  end

  ###### GET By Id ######
  %path_id_param = Open::Api::Parameter.new(
    %model_def.primary_key,
    %model_def.primary_key_type,
    location: "path",
    description: "id of record", required: true
  )
  %open_api.add_path("/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}", Open::Api::Operation::Get,
    item: Spoved::Kemal.create_get_op_item(
      model_name: %model_def.name,
      params: [
        %path_id_param
      ],
      resp_ref: %open_api.schema_ref(%model_def.name)
    )
  )

  Spoved::Kemal.register_route("GET", "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}", {{model.id}})
  get "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}" do |env|
    env.response.content_type = "application/json"
    id = env.params.url[%model_def.primary_key]
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
  Spoved::Kemal.register_route("DELETE", "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}", {{model.id}})
  %open_api.add_path("/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}", Open::Api::Operation::Delete,
    item: Spoved::Kemal.create_delete_op_item(
      model_name: %model_def.name,
      params: [
        %path_id_param
      ],
    )
  )

  delete "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}" do |env|
    env.response.content_type = "application/json"
    env.response.content_type = "application/json"
    id = env.params.url[%model_def.primary_key]
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
  Spoved::Kemal.register_route("PUT", "/api/#{%api_version}/#{%path}", {{model.id}})
  %open_api.add_path("/api/#{%api_version}/#{%path}", Open::Api::Operation::Put,
    item: Spoved::Kemal.create_put_op_item(
      model_name: %model_def.name,
      model_ref: %open_api.schema_ref(%model_def.name),
      body_schema: Spoved::Kemal.body_schema({{model.id}}),
    )
  )

  put "/api/#{%api_version}/#{%path}" do |env|
    env.response.content_type = "application/json"

    item = {{model}}.new
    values = Spoved::Kemal.param_args(env, %patch_body_params)
    %model_def.patch_item.call(item, values)

    # item = {{model}}.from_json(env.request.body.not_nil!)
    item.save!
    Spoved::Kemal.set_content_length(item.to_json, env)
  rescue ex
    Log.error(exception: ex) {ex.message}
    Spoved::Kemal.resp_400(env, ex.message)
  end

  ###### PATCH ######

  Spoved::Kemal.register_route("PATCH", "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}", {{model.id}})
  %open_api.add_path("/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}", Open::Api::Operation::Patch,
    item: Spoved::Kemal.create_patch_op_item(
      model_name: %model_def.name,
      params: [
        %path_id_param
      ],
      body_object: %patch_body_object,
      model_ref: %open_api.schema_ref(%model_def.name)
    )
  )

  patch "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}" do |env|
    env.response.content_type = "application/json"
    id = env.params.url[%model_def.primary_key]
    Log.notice &.emit "patch {{model.id}}", id: id
    item = {{model.id}}.find({{id_class}}.new(id))
    if item.nil?
      Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
    else
      values = Spoved::Kemal.param_args(env, %patch_body_params)
      %model_def.patch_item.call(item, values)
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
      %target_object_name = Spoved::Kemal._api_model_name({{anno[:target]}})
      Log.debug {"registering relationship: #{%model_def.name} -> #{%target_object_name}, type: {{anno[:type]}}"}
      Spoved::Kemal.define_relationships(
        {{model.id}},
        %model_def,
        {{meth.name}},
        Spoved::Kemal::ModelDef({{anno[:target]}}).new(
          %target_object_name, "#{%path}/{#{%model_def.primary_key}}/#{%target_object_name}"
        ),
        {{anno[:type]}}, {{anno[:target]}}, :{{anno[:foreign_key]}},
        %path_id_param, %api_version, {{id_class}})
    {% end %}
  {% end %}
end
