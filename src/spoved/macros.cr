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
