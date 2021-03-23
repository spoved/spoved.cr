require "uuid"
require "uuid/json"

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
