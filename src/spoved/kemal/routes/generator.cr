require "./register"
require "./functions"

# Generates CRUD routes for `Epidote` models
macro crud_routes(model, path, filter = nil, id_class = UUID, formatter = nil, schema = nil)
  {% if model.resolve < Epidote::Model %}

  {% mysql_type = (model.resolve.ancestors.find(&.id.==("Epidote::Model::MySQL"))) ? true : false %}
  Log.notice &.emit "Generating CRUD routes for {{model}}", mysql_type: {{mysql_type}}

  register_route("GET", "/api/v1/{{path.id}}", {{model.id}}, {{filter}}, true, {{schema}})
  get "/api/v1/{{path.id}}" do |env|
    env.response.content_type = "application/json"
    limit, offset = Spoved::Kemal.limit_offset_args(env)
    {% if mysql_type %}
    order_by = Spoved::Kemal.order_by_args(env)
    {% end %}

    # Handle querying filter here
    {% if filter %}
      active_query = !(
        {{ filter.keys.map { |k| "env.params.query[\"#{k}\"]?.nil?" }.join(" && ") }}
      )

      q_params = {
        {% for k, t in filter %}
          {{k}}: env.params.query["{{k}}"]?.nil? ? nil : {{t.gsub(/%/, "env.params.query[\"#{k}\"]").id}},
        {% end %}
      }

      # Log.warn { "Query with limit: #{limit}"}
      resp_items = {{model}}.query(
          **q_params,
          limit: limit,
          offset: offset,
        {% if mysql_type %}
          order_by: order_by,
        {% end %}
      )

      total = if active_query
                {{model}}.size(**q_params)
              else
                {{model}}.size
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
    # pp env.request.body.not_nil!
    resp = {{model}}.from_json(env.request.body.not_nil!).save!
    Spoved::Kemal.set_content_length(resp.to_json, env)
  end

  {% m = model.resolve %}
  {% if m.constant("ATTR_TYPES") %}

  register_route("PATCH", "/api/v1/{{path.id}}/:id",  {{model.id}})
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
        if {{model}}::CONVERTERS[:{{key.id}}]? && data[{{key.id.stringify}}].is_a?(String)
          %val = {{model}}::CONVERTERS.fetch(:{{key.id}}, nil).try &.from_s(data[{{key.id.stringify}}].as(String))
          patch_data[{{key}}] = %val.as({{typ}})
        else
          patch_data[{{key}}] = data[{{key.id.stringify}}].as({{typ}})
        end
      end
      {% end %}{% end %}

      r.update_attrs(patch_data)
      resp = r.update!
      Spoved::Kemal.set_content_length(r.to_json, env)
    end
  end
  {% else %}
  {% raise "Unable to generate patch routes. Please define crud_routes last in your app" %}
  {% end %} # end if m.constant("ATTR_TYPES")

  {% else %}{% raise "only support sub classes of Epidote::Model" %}{% end %}
end
