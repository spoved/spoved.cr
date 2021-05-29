macro enum_from_string(_enum)
  def {{_enum.id}}.new(val : String) : {{_enum.id}}
    {{_enum.id}}.from_s(val)
  end

  def {{_enum.id}}.from_s(val : String) : {{_enum.id}}
    case val
    {% for t in _enum.resolve.constants %}
    when {{ [t.underscore.downcase.stringify, t.downcase.stringify].uniq.join(", ") }}
      {{t.id}}
    {% end %}
    else
      raise "Unknown {{_enum.id}}: #{val}"
    end
  end
end

macro enum_to_const(name, _enum)
  {{name.upcase.id}} = [
    {% for t in _enum.resolve.constants %}
    {{t.underscore.downcase.stringify}},
    {% end %}
  ]
end

# Creates a `Epidote` converter for the provided enum
macro enum_converter(e, mysql = false, bson = false, yaml = false)
  {% if !e.resolve.class.has_method?("from_s") %}
  enum_from_string {{e}}
  {% end %}

  {% klass = e.resolve %}
  struct ::{{klass.id}}Converter
    def self.to_bson(value)
      value.to_s.downcase
    end

    def self.from_bson(bson)
      ::{{klass.id}}.from_s(bson.to_s)
    end

    def self.from_json(pull : JSON::PullParser)
      ::{{klass.id}}.from_s(pull.read_string)
    end

    def self.to_json(value : ::{{klass.id}}, json : JSON::Builder)
      value.to_s.downcase.to_json(json)
    end

    {% if mysql %}
    def self.mysql_type
      MySql::Type::String
    end

    def self.to_mysql(value : ::{{klass.id}})
      value.to_s
    end

    def self.from_mysql(str : String) : ::{{klass.id}}
      ::{{klass.id}}.from_s(str)
    end
    {% end %}

    {% if yaml %}
    def self.to_yaml(value : ::{{klass.id}})
      String.build do |io|
        to_yaml(value, io)
      end
    end

    def self.to_yaml(value : ::{{klass.id}}, io : IO)
      nodes_builder = YAML::Nodes::Builder.new
      to_yaml(value, nodes_builder)

      # Then we convert the tree to YAML.
      YAML.build(io) do |builder|
        nodes_builder.document.to_yaml(builder)
      end
    end

    def self.to_yaml(member : ::{{klass.id}}, yaml : YAML::Nodes::Builder)
      yaml.scalar(member.to_s.downcase)
    end


    def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : ::{{klass.id}}
      from_yaml(ctx, node)
    end

    # Reads a serialized enum member by value from *ctx* and *node*.
    #
    # See `.to_yaml` for reference.
    #
    # Raises `YAML::ParseException` if the deserialization fails.
    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : ::{{klass.id}}
      value = String.new ctx, node
      ::{{klass.id}}.from_s(value.downcase) || node.raise "Unknown enum ::{{klass.id}} value: #{value}"
    end
    {% end %}
  end
end
