require "./register"

def limit_offset_args(env)
  limit = env.params.query["limit"]?.nil? ? DEFAULT_LIMIT : env.params.query["limit"].to_i
  offset = env.params.query["offset"]?.nil? ? 0 : env.params.query["offset"].to_i

  {limit, offset}
end

def order_by_args(env)
  order_by = env.params.query["order_by"]?.nil? ? nil : env.params.query["order_by"]
  if order_by.nil?
    Array(String).new
  else
    order_by.split(',')
  end
end

macro crud_routes(model, path, filter = nil, id_class = UUID, formatter = nil, schema = nil)
  Log.notice {"Generating CRUD routes for {{model}}"}
  {% mysql_type = (model.resolve.ancestors.find(&.id.==("Epidote::Model::MySQL"))) %}

  register_route("GET", "/api/v1/{{path.id}}", {{model.id}}, {{filter}}, true, {{schema}})
  get "/api/v1/{{path.id}}" do |env|
    limit, offset = limit_offset_args(env)
    {% if mysql_type %}
    order_by = order_by_args(env)
    {% end %}

    # Handle querying filter here
    {% if filter %}
      {% for k, t in filter %}
        _query_{{k}} = env.params.query["{{k}}"]?
        # puts " _query_{{k}} : #{ _query_{{k}}}"
      {% end %}
      {% query_test = filter.keys.map { |k| "_query_#{k}.nil?" }.join(" && ") %}
      active_query = !({{query_test.id}})

      if(active_query)
        limit = 0
        offset = 0
      end

      # Log.warn { "Query with limit: #{limit}"}
      resp_items = {{model}}.query(
        limit: limit,
        offset: offset,

        {% if mysql_type %}
        order_by: order_by,
        {% end %}

        {% for k, t in filter %}
          {% f = t.gsub(/%/, "_query_#{k}") %}
          {{k}}: _query_{{k}}.nil? ? nil : {{f.id}},
        {% end %}
      )

      if active_query
        total = resp_items.size
      else
        total = {{model}}.size
      end
    {% else %}
      total = {{model}}.size
      resp_items = {{model}}.query(limit: limit, offset: offset)
    {% end %}

    # Format response if formatter was provided
    {% if formatter %}
      formatter =  {{formatter}}
      resp_items = resp_items.map &formatter
    {% end %}

    resp = response_data(limit, offset, resp_items, total)
    set_content_length(resp.to_json, env)
  end

  register_route("GET", "/api/v1/{{path.id}}/:id", {{model.id}})
  get "/api/v1/{{path.id}}/:id" do |env|
    id = env.params.url["id"]
    resp = {{model}}.find({{id_class}}.new(id))

    if resp.nil?
      not_found_resp(env, "Record with id: #{id} not found")
    else
      # Format response if formatter was provided
      {% if formatter %}
        formatter =  {{formatter}}
        resp = formatter.call(resp)
      {% end %}

      set_content_length(resp.to_json, env)
    end
  end

  register_route("DELETE", "/api/v1/{{path.id}}/:id", {{model.id}})
  delete "/api/v1/{{path.id}}/:id" do |env|
    id = env.params.url["id"]
    r = {{model}}.find({{id_class}}.new(id))
    if r.nil?
      not_found_resp(env, "Record with id: #{id} not found")
    else
      r.destroy!
      resp_204(env)
    end
  end

  register_route("PUT", "/api/v1/{{path.id}}", {{model.id}})
  put "/api/v1/{{path.id}}" do |env|
    resp = {{model}}.from_json(env.request.body.not_nil!).save!
    set_content_length(resp.to_json, env)
  end
end
