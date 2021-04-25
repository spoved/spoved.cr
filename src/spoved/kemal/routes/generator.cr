require "./register"
require "./functions"

# Generates CRUD routes for `Epidote` models
macro crud_routes(model, path, filter = nil, id_class = UUID, formatter = nil, schema = nil)
  {% if model.resolve < Epidote::Model %}

  Log.notice {"Generating CRUD routes for {{model}}"}
  {% mysql_type = (model.resolve.ancestors.find(&.id.==("Epidote::Model::MySQL"))) %}

  register_route("GET", "/api/v1/{{path.id}}", {{model.id}}, {{filter}}, true, {{schema}})
  get "/api/v1/{{path.id}}" do |env|
    env.response.content_type = "application/json"

    limit, offset = Spoved::Kemal.limit_offset_args(env)
    {% if mysql_type %}
    order_by = Spoved::Kemal.order_by_args(env)
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

    resp = Spoved::Kemal.response_data(limit, offset, resp_items, total)
    Spoved::Kemal.set_content_length(resp.to_json, env)
  end

  register_route("GET", "/api/v1/{{path.id}}/:id", {{model.id}})
  get "/api/v1/{{path.id}}/:id" do |env|
    env.response.content_type = "application/json"

    id = env.params.url["id"]
    resp = {{model}}.find({{id_class}}.new(id))

    if resp.nil?
      Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
    else
      # Format response if formatter was provided
      {% if formatter %}
        formatter =  {{formatter}}
        resp = formatter.call(resp)
      {% end %}

      Spoved::Kemal.set_content_length(resp.to_json, env)
    end
  end

  register_route("DELETE", "/api/v1/{{path.id}}/:id", {{model.id}})
  delete "/api/v1/{{path.id}}/:id" do |env|
    env.response.content_type = "application/json"

    id = env.params.url["id"]
    r = {{model}}.find({{id_class}}.new(id))
    if r.nil?
      Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
    else
      r.destroy!
      Spoved::Kemal.resp_204(env)
    end
  end

  register_route("PUT", "/api/v1/{{path.id}}", {{model.id}})
  put "/api/v1/{{path.id}}" do |env|
    env.response.content_type = "application/json"

    resp = {{model}}.from_json(env.request.body.not_nil!).save!
    Spoved::Kemal.set_content_length(resp.to_json, env)
  end

  {% m = model.resolve %}
  {% if m.constant("ATTR_TYPES") %}

  {% puts "adding patch route for #{model}" %}
  # register_route("PATCH", "/api/v1/{{path.id}}/:id",  {{model.id}})
  patch "/api/v1/{{path.id}}/:id" do |env|
    env.response.content_type = "application/json"
    id = env.params.url["id"]
    r = {{model}}.find({{id_class}}.new(id))
    if r.nil?
      Spoved::Kemal.not_found_resp(env, "Record with id: #{id} not found")
    else

     data = Hash(String, {% for key, typ in m.constant("ATTR_TYPES") %}{% if key.id != m.constant("PRIMARY_KEY") %} {{typ}} | {% end %}{% end %} Nil).from_json(
        env.request.body.not_nil!
      )
      # data = JSON.parse(env.request.body.not_nil!)
      patch_data = Hash(Symbol, {{model}}::ValTypes).new

      {% for key, typ in m.constant("ATTR_TYPES") %}
      # Skip updating primary key
      {% if key.id != m.constant("PRIMARY_KEY") %}
      if data[{{key.id.stringify}}]?
        patch_data[{{key}}] = data[{{key.id.stringify}}].as({{typ}})
      end
      {% end %}{% end %}

      r.update_attrs(patch_data)
      resp = r.update!
      Spoved::Kemal.set_content_length(r.to_json, env)
    end
  end
  {% end %} # end if m.constant("ATTR_TYPES")

  {% else %}{% raise "only support sub classes of Epidote::Model" %}{% end %}
end
