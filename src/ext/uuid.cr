require "uuid"
require "uuid/json"

# Needed until https://github.com/crystal-lang/crystal/pull/10517 is merged
def UUID.from_json_object_key?(key : String)
  UUID.new(key)
end
