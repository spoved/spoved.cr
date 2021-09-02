module Spoved::Kemal
  macro body_schema(_model)
    Open::Api::Schema.new("object").tap do |schema|
      {% model = _model.resolve %}
      {% columns = [] of MetaVar %}
      {% enum_check = {} of StringLiteral => BoolLiteral %}
      {% for var in model.instance_vars %}
        {% if var.annotation(Granite::Column) %}
          {% enum_check[var.id] = var.type.union_types.first < Enum %}
          {% if var.id == :created_at || var.id == :modified_at %}
            # skip created_at/modified_at
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

  macro define_relationships(_model, model_def, meth_name, target_model_def, rel_type, rel_target, foreign_key,
                             path_id_param, api_version = "v1", id_class = UUID)
    {% model = _model.resolve %}
    %model_def = {{model_def}}
    %target_model_def = {{target_model_def}}
    %api_version = {{api_version}}
    %path = %model_def.path
    %open_api = %model_def.open_api
    %path_id_param = {{path_id_param}}

    Spoved::Kemal.register_schema({{rel_target}}, %target_model_def)

    {% if rel_type == :has_one || rel_type == :belongs_to %}
      %_path_ = "/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}/#{%target_model_def.name}"
      %open_api.add_path(%_path_, Open::Api::Operation::Get,
        item: Spoved::Kemal.create_get_op_item(
          operation_id: "get_#{%model_def.name}_#{%target_model_def.name}",
          model_name: %model_def.name,
          params: [
            %path_id_param
          ],
          resp_ref: %open_api.schema_ref(%target_model_def.name)
        )
      )
      %_kemal_path = "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}/#{%target_model_def.name}"
      Spoved::Kemal.register_route("GET", %_kemal_path, {{model.id}})
      get %_kemal_path do |env|
        env.response.content_type = "application/json"
        id = env.params.url[%model_def.primary_key]
        item = {{model.id}}.find({{id_class}}.new(id))
        if item.nil?
          Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
        else
          Spoved::Kemal.set_content_length(item.{{meth_name}}.to_json, env)
        end
      rescue ex
        Log.error(exception: ex) {ex.message}
        Spoved::Kemal.resp_400(env, ex.message)
      end

    {% elsif rel_type == :has_many %}
      %resp_list_object_name, %resp_list_object = Spoved::Kemal.create_list_schemas(%target_model_def.name)
      if !%open_api.has_schema_ref?(%resp_list_object_name)
        %open_api.register_schema(%resp_list_object_name, %resp_list_object)
      end

      %_path_ = "/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}/#{%target_model_def.name.pluralize}"
      %open_api.add_path(%_path_, Open::Api::Operation::Get,
        item: Spoved::Kemal.create_get_list_op_item(
          operation_id: "get_#{%model_def.name}_#{%target_model_def.name}_list",
          model_name: %model_def.name,
          params: [
            Spoved::Kemal.list_req_params,
            %target_model_def.coll_filter_params,
            %path_id_param,
          ].flatten,
          resp_ref: %open_api.schema_ref(%resp_list_object_name)
        )
      )

      %_kemal_path = "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}/#{%target_model_def.name.pluralize}"
      Spoved::Kemal.register_route("GET", %_kemal_path, {{model.id}})
      get %_kemal_path do |env|
        env.response.content_type = "application/json"
        limit, offset = Spoved::Kemal.limit_offset_args(env)
        sort_by, sort_order = Spoved::Kemal.sort_args(env)
        id = env.params.url[%model_def.primary_key]
        filters = Spoved::Kemal.param_args(env, %target_model_def.coll_filter_params)
        query = {{rel_target}}.where({{foreign_key.id}}: {{id_class}}.new(id))

        # If sort is not specified, sort by provided column
        %target_model_def.sort_by.call(sort_by, sort_order, query)

        # If filters are specified, apply them
        %target_model_def.apply_filters.call(filters, query)

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

  end
end
