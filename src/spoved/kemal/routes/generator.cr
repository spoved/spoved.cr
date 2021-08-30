require "./register"
require "./functions"
require "./epidote_gen"
require "./granite_gen"

# Generates CRUD routes for `Epidote` models
macro crud_routes(model, path, filter = nil, id_class = UUID, formatter = nil, schema = nil)
  {% if model.resolve < Epidote::Model %}
  epidote_gen_routes({{model}}, {{path}}, {{filter}}, {{id_class}}, {{formatter}}, {{schema}})
  {% elsif model.resolve < Granite::Base %}
  granite_gen_routes({{model}}, {{path}}, {{filter}}, {{id_class}}, {{formatter}}, {{schema}})
  {% else %}
  {% raise "only support sub classes of Epidote::Model" %}
  {% end %}
end
