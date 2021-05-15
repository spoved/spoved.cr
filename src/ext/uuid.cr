require "uuid"
require "uuid/json"
require "yaml"

# Needed until https://github.com/crystal-lang/crystal/pull/10517 is merged
struct UUID
  # :nodoc:
  def to_json_object_key
    to_s
  end

  # Deserializes the given JSON *key* into a `UUID`.
  #
  # NOTE: `require "uuid/json"` is required to opt-in to this feature.
  def self.from_json_object_key?(key : String)
    UUID.new(key)
  end
end

# Needed until https://github.com/crystal-lang/crystal/pull/10715 is merged
def UUID.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  ctx.read_alias(node, String) do |obj|
    return UUID.new(obj)
  end

  if node.is_a?(YAML::Nodes::Scalar)
    value = node.value
    ctx.record_anchor(node, value)
    UUID.new(value)
  else
    node.raise "Expected String, not #{node.kind}"
  end
end

struct UUID
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar self.to_s
  end
end
