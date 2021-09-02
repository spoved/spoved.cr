module Spoved::Kemal
  # :nodoc:
  alias PropertyTypes = Int32.class | Int64.class | Nil.class | UUID.class | Bool.class | String.class |
                        (Int32 | Nil).class | (Int64 | Nil).class | (UUID | Nil).class | (Bool | Nil).class | (String | Nil).class

  # :nodoc:
  class ModelDef(T)
    getter name : String
    getter path : String
    getter properties : Hash(String, Open::Api::SchemaRef) = Hash(String, Open::Api::SchemaRef).new
    getter collumn_params : Array(Spoved::Kemal::CollParamDef) = [] of Spoved::Kemal::CollParamDef
    getter body_params : Array(Open::Api::Parameter) = Array(Open::Api::Parameter).new
    getter resp_list_object_name : String
    getter resp_list_object : Open::Api::SchemaRef
    property sort_by : Proc(Array(String), String, Granite::Query::Builder(T), Nil) = ->(sort_by : Array(String), sort_order : String, query : Granite::Query::Builder(T)) {}
    property apply_filters : Proc(Array(Spoved::Kemal::ParamFilter), Granite::Query::Builder(T), Nil) = ->(filters : Array(Spoved::Kemal::ParamFilter), query : Granite::Query::Builder(T)) {}
    property patch_item : Proc(T, Array(ParamFilter), Nil) = ->(item : T, filters : Array(Spoved::Kemal::ParamFilter)) {}

    def initialize(@name, @path)
      {% model = @type.type_vars.first %}
      @resp_list_object_name, @resp_list_object = Spoved::Kemal.create_list_schemas(@name)

      populate_model_def({{@type.type_vars.first.id}}, self)

      @collumn_params.select { |c| c.name != "created_at" && c.name != "created_at" }.map(&.coll_param).each do |param|
        @body_params << Open::Api::Parameter.new(
          name: param.name,
          parameter_in: "body",
          required: param.required,
          schema: param.schema
        )
      end
    end

    def coll_names : Array(String)
      self.collumn_params.map(&.name)
    end

    def coll_filter_params : Array(Open::Api::Parameter)
      self.collumn_params.reject(&.primary).flat_map(&.filter_params)
    end

    def coll_params : Array(Open::Api::Parameter)
      self.collumn_params.reject(&.primary).map(&.coll_param)
    end

    def primary_key : String
      self.collumn_params.find(&.primary).not_nil!.name
    end

    def primary_key_type : PropertyTypes
      self.collumn_params.find(&.primary).not_nil!.type
    end

    def open_api
      Spoved::Kemal.open_api
    end

    private macro populate_model_def(_model, model_def)
      {% model = _model.resolve %}
      %model_def = {{model_def}}

      {% primary_key = model.instance_vars.find { |var| var.annotation(Granite::Column) && var.annotation(Granite::Column)[:primary] } %}
      {% id_class = primary_key.type.union_types.first %}
      {% columns = [] of MetaVar %}
      {% enum_check = {} of StringLiteral => BoolLiteral %}
      {% for var in model.instance_vars %}
        {% if var.annotation(Granite::Column) %}
          {% is_enum = var.type.union_types.first < Enum %}
          {% if is_enum %}{% enum_check[var.id] = is_enum %}{% end %}

          %model_def.collumn_params << Spoved::Kemal::CollParamDef.new(
            name: "{{var.id}}",
            type: {% if enum_check[var.id] %}String{% else %}{{var.type.union_types.first}}{% end %},
            primary: {{var.annotation(Granite::Column)[:primary] ? true : false}},
            default_value: {% if var.has_default_value? %}{{var.default_value.id}}{% if enum_check[var.id] %}.to_s{% end %}{% else %}nil{% end %},
            filter_params: Spoved::Kemal.filter_params_for_var("{{var.id}}", {% if enum_check[var.id] %}String{% else %}{{var.type}}{% end %}),
            coll_param: Open::Api::Parameter.new(
              "{{var.id}}",
              {% if enum_check[var.id] %}String{% else %}{{var.type}}{% end %},
              description: "return results that match {{var.id}}",
              default_value: {% if var.has_default_value? %}{{var.default_value.id}}{% if enum_check[var.id] %}.to_s{% end %}{% else %}nil{% end %}
            ),
          )

          %model_def.properties[{{var.id.stringify}}] = Open::Api::Schema.new(
            {% if enum_check[var.id] %}
            schema_type: "string",
            format: "string",
            default: {{var.default_value.id}}.to_s,
            {% else %}
            schema_type: Open::Api.get_open_api_type({{var.type}}),
            format: Open::Api.get_open_api_format({{var.type}}),
            default: {{var.default_value.id}}
            {% end %}
          )

          {% if var.annotation(Granite::Column)[:primary] %}
            # skip the primary key
          {% else %}
            {% columns << var %}
          {% end %}
        {% end %}
      {% end %}

      %model_def.sort_by = ->(sort_by: Array(String), sort_order : String, query : Granite::Query::Builder({{model.id}})){
        sort_by.each do |v|
          case v
          when "{{primary_key.id}}"
            query.order({{primary_key.id}}: sort_order == "desc" ? :desc : :asc)
          {% for column in columns %}
          when "{{column.id}}"
            query.order({{column.id}}: sort_order == "desc" ? :desc : :asc)
          {% end %}
          end
        end
      }

      %model_def.apply_filters = ->(filters : Array(Spoved::Kemal::ParamFilter), query : Granite::Query::Builder({{model.id}})){
        filters.each do |filter|
          case filter[:name]
          when "{{primary_key.id}}"
            query.where(filter[:name], filter[:op], {{id_class}}.new(filter[:value].as(String)))
          {% for column in columns %}
          when "{{column.id}}"
            # Check if the column is an UUID
            {% if column.type.union_types.first <= UUID %}
            query.where(filter[:name], filter[:op], UUID.new(filter[:value].as(String)))
            {% else %}
            query.where(filter[:name], filter[:op], filter[:value])
            {% end %}
          {% end %}
          end
        end
      }

      %model_def.patch_item = ->(item : {{model.id}}, values : Array(Spoved::Kemal::ParamFilter)){
        pp values
        values.each do |param|
          case param[:name]
          when "{{primary_key.id}}"
            Log.warn { "patching attr {{primary_key.id}}" }
            item.{{primary_key.id}} = {{id_class}}.new(param[:value].as(String))
          {% for column in columns %}
          when "{{column.id}}"
            Log.warn { "patching attr {{column.id}}" }
            {% if enum_check[column.id] %}
            item.{{column.id}} =  {{column.type.union_types.first}}.parse(param[:value].as(String))
            {% elsif column.type.union_types.first <= UUID %}
            item.{{column.id}} = UUID.new(param[:value].as(String))
            {% elsif column.type.union_types.first <= Int32 %}
            %var = param[:value].as(Int64)
            item.{{column.id}} = %var.to_i unless %var.nil?
            {% else %}
            %var = param[:value].as({{column.type}})
            item.{{column.id}} = %var unless %var.nil?
            {% end %}
          {% end %}
          else
            raise "unable to patch item attribute: #{param[:name]}"
          end
        end
      }
    end
  end

  # :nodoc:
  record CollParamDef, name : String, primary : Bool, coll_param : Open::Api::Parameter, filter_params : Array(Open::Api::Parameter),
    type : PropertyTypes,
    default_value : Int32 | Int64 | Nil | UUID | Bool | String do
  end
end
