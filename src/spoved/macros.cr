macro enum_from_string(_enum)
  def {{_enum.id}}.new(val : String) : {{_enum.id}}
    case val
    {% for t in _enum.resolve.constants %}
    when {{ t.underscore.downcase.stringify }}
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

macro enum_converter(e)
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
  end
end
