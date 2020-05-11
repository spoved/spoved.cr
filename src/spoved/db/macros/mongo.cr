abstract class Spoved::DB::Model::Mongo < Spoved::DB::Model
  # :nodoc:
  annotation Spoved::DB::Model::Mongo::Method; end

  macro model(collection, attributes, converters, use_expire = false)
    include JSON::Serializable

    def self.collection
      {{collection.id.stringify}}
    end

    def collection
      self.class.collection
    end

    def primary_key_value
      self.id
    end

    def initialize(
      {% for name, val in attributes %}
        {% if name.id == "id" || name.id == "_id" %}
          {% raise "Cannot use _id or id as an attribute. this is handled automatically." %}
        {% end %}
        {% if val.id == "UUID" || val.id == "JSON::Any" %}
          {{name}} : String | {{val}},
        {% else %}
          {{name}} : {{val}},
        {% end %}
      {% end %}
      {% if use_expire %}
      @is_expired = false,
      {% end %}
      id : String | BSON::ObjectId = BSON::ObjectId.new,
    )

      @id = id.is_a?(String) ? BSON::ObjectId.new(id) : id
      {% for name, val in attributes %}
        {% if val.id == "UUID" %}
          @{{name}} = {{name}}.is_a?(String) ? UUID.new({{name}}) : {{name}}
        {% elsif val.id == "JSON::Any" %}
          @{{name}} = {{name}}.is_a?(String) ? JSON.parse({{name}}) : {{name}}
        {% else %}
        @{{name}} = {{name}}
        {% end %}
      {% end %}
    end

    {% if use_expire %}
      @[JSON::Field(ignore: true)]
      @[Spoved::DB::Model::Mongo::Method(:getter)]
      property is_expired : Bool
    {% end %}

    @[JSON::Field(key: "_id")]
    @[Spoved::DB::Model::Mongo::Method]
    property id : BSON::ObjectId = BSON::ObjectId.new
    def id=(value : String)
      self.id = BSON::ObjectId.new value
    end

    private def _id=(value : BSON::ObjectId)
      self.id = value
    end

    private def _id  : BSON::ObjectId
      self.id
    end

    {% for name, val in attributes %}
      # Set our class properites here
      @[JSON::Field]
      @[Spoved::DB::Model::Mongo::Method]
      property {{name}} : {{val}}

      {% if val.id == "UUID" %}
        @[Spoved::DB::Model::Mongo::Method(:setter)]
        def {{name}}=(val : String)
          self.{{name}} = UUID.new(val)
        end
      {% elsif val.id == "JSON::Any" %}
        @[Spoved::DB::Model::Mongo::Method(:setter)]
        def {{name}}=(val : String)
          self.{{name}} = JSON.parse(val)
        end
      {% end %}
    {% end %}


    # All the possible `typeof(val)` for each property
    alias ValTypes = BSON::ObjectId {% for name, val in attributes %} | {{val}} {% end %}

    # Array of all the attributes names
    protected def self.attributes : Array(String)
      {{ attributes.keys.map &.stringify }}
    end

    private def attr_hash
      hash = Hash(String, ValTypes).new
      attributes.each do |k|
        hash[k] = get(k)
      end
      hash
    end

    # Will convert the `{{@type}}::DataHash` into an object
    protected def self.from_bson(bson : BSON)
      new_ob = self.allocate
      bson.each_key do |%key|
        %value = bson[%key]
        case %key
        when "_id"
          new_ob.id = %value.as(BSON::ObjectId)
        {% for name, val in attributes %}
        when {{name.stringify}}
          {% if converters[name] %}
          new_ob.set {{name.stringify}}, {{converters[name]}}(%value.as(BSON))
          {% else %}
          new_ob.set {{name.stringify}}, %value.as({{val}})
          {% end %}
        {% end %}
        else
          raise "Unable to set #{%key} with #{%value.inspect}"
        end
      end
      new_ob
    end

    private def self._query_all(
      where = "",
      {% if use_expire %}
        expired = false
      {% end %}
      )
      results = [] of {{@type}}
      with_collection do |coll|
        coll.find(BSON.new) do |doc|
          results << from_bson(doc)
        end
      end

      results
    end

    # Return an array containing all of the `{{@type}}` records
    def self.all : Array({{@type}})
      self._query_all
    end

    def self.query(id : String | BSON::ObjectId | Nil = nil,
      {% for name, val in attributes %}
        {{name}} : {{val}}? = nil,
      {% end %}
      {% if use_expire %}
        expired = false
      {% end %}
    )
    end

    # Find a single record based on primary key
    def self.find(id : String | BSON::ObjectId) : {{@type}}?
      result : {{@type}}? = nil
      with_collection do |col|
        bson = col.find_one({"_id" => id})
        result = from_bson(bson) unless bson.nil?
      end
      result
    rescue ex
      logger.error(exception: ex) { "Error when trying to locate record with id: #{id.to_s}" }
    end

    private def _delete_record
      {{@type}}.with_collection do |coll|
        coll.remove({"_id" => id})
        if (err = coll.last_error)
          return err["nRemoved"] == 1 ? true : false
        else
          return false
        end
      end
      false
    end

    {% if use_expire %}
    # TODO: Validate this behavior
    private def _unexpire_record
    rescue ex
      logger.error { ex }
      false
    end
    {% end %}

    private def _insert_record
      {% if use_expire %}
      if self.is_expired
        raise "Can not update expired record!"
      end
      {% end %}
      {{@type}}.with_collection do |coll|
        doc = BSON.from_json(self.to_json)

        if doc.has_key?("id")
          doc["_id"] = BSON::ObjectId.new(doc["id"].to_s)
          doc["id"] = nil
        end

        coll.insert(doc)
        if (err = coll.last_error)
          return doc["_id"].to_s.chomp('\u0000')
        end
      end
    end

    private def _update_record
      {% if use_expire %}
      if self.is_expired
        raise "Can not update expired record!"
      end
      {% end %}
      {{@type}}.with_collection do |coll|
        coll.update({"_id" => id}, {"$set" => self.attr_hash})
      end
    end

    def get(%name : Symbol | String) : ValTypes
      case %name.to_s
      {% for name, val in attributes %}
      when {{name.stringify}}
        self.{{name}}
      {% end %}
      else
        raise "Could not get |#{%name}|"
      end
    end

    def set(%name : Symbol | String, %value : ValTypes)
      logger.debug { "#{primary_key_value} : setting #{%name} to #{%value}" }

      case %name.to_s
      {% for name, val in attributes %}
      when {{name.stringify}}
        raise "Expected {{name}} to be of type {{val}} not #{typeof(%value)}" unless %value.is_a?({{val}})
        self.{{name}} = %value
      {% end %}
      else
        raise "Could not set |#{%name}|"
      end
    end

    def update_attrs(changes : Hash(String | Symbol, ValTypes))
      changes.each do |n, v|
        raise "Unknown attribute" unless {{@type}}.attributes.includes?(n.to_s)
        raise "Can not change primary key" if n.to_s == "id"

        self.set(n, v)
      end
    end

    def self.create(**args)
      obj = self.new(**args)
      obj.save
      obj
    end
  end
end
