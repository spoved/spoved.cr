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
macro enum_converter(e, mysql = false)
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
  end
end
