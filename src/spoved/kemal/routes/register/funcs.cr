module Spoved::Kemal
  SPOVED_ROUTES = Array(Array(String)).new
  SWAGGER_API   = Open::Api.new
  # :nodoc:
  DEFAULT_LIMIT = 100
  # :nodoc:
  NUM_OPERATORS = %w(:gteq :lteq :neq :gt :lt :nlt :ngt :ltgt)
  # :nodoc:
  STRING_OPERATORS = %w(:in :nin :like :nlike)

  def open_api : Open::Api
    SWAGGER_API
  end

  def list_req_params
    [
      SWAGGER_API.parameter_ref("resp_limit"),
      SWAGGER_API.parameter_ref("resp_offset"),
      SWAGGER_API.parameter_ref("resp_sort_by"),
      SWAGGER_API.parameter_ref("resp_sort_order"),
    ]
  end

  private def register_default_schemas
    SWAGGER_API.register_schema("error", Open::Api::Schema.new(
      schema_type: "object",
      properties: Hash(String, Open::Api::SchemaRef){
        "code"    => Open::Api::Schema.new("integer", format: "int32"),
        "message" => Open::Api::Schema.new("string"),
      },
    ))
  end

  private def register_default_parameters
    {
      "resp_limit" => Open::Api::Parameter.new(
        "limit", Int32?, location: "query",
        description: "limit the number of results returned (default: 100)",
        required: false, default_value: DEFAULT_LIMIT
      ),
      "resp_offset" => Open::Api::Parameter.new(
        "offset", Int32?, location: "query",
        description: "offset the results returned",
        required: false, default_value: 0
      ),
      "resp_sort_by" => Open::Api::Parameter.new(
        "sort_by", String?, location: "query",
        description: "sort the results returned by provided field.",
        required: false, default_value: nil
      ),
      "resp_sort_order" => Open::Api::Parameter.new(
        "sort_order", String?, location: "query",
        description: "sort the results returned in the provided order (asc, desc).",
        required: false, default_value: nil
      ),
    }.each do |name, param|
      SWAGGER_API.register_parameter name, param
    end
  end

  private def register_default_responses
    error_content = {
      "application/json" => Open::Api::MediaType.new(SWAGGER_API.schema_ref("error")),
    }
    default_responses = {
      "204"     => Open::Api::Response.new(description: "successfully deleted record"),
      "400"     => Open::Api::Response.new(description: "Bad Request", content: error_content),
      "401"     => Open::Api::Response.new(description: "Unauthorized", content: error_content),
      "403"     => Open::Api::Response.new(description: "Forbidden", content: error_content),
      "404"     => Open::Api::Response.new(description: "Not Found", content: error_content),
      "500"     => Open::Api::Response.new(description: "Internal Server Error", content: error_content),
      "default" => Open::Api::Response.new(description: "Unknown Error", content: error_content),
    }

    default_responses.each do |code, response|
      SWAGGER_API.register_response(code, response)
    end
  end

  def default_response_refs
    {
      "400"     => SWAGGER_API.response_ref("400"),
      "401"     => SWAGGER_API.response_ref("401"),
      "403"     => SWAGGER_API.response_ref("403"),
      "404"     => SWAGGER_API.response_ref("404"),
      "500"     => SWAGGER_API.response_ref("500"),
      "default" => SWAGGER_API.response_ref("default"),
    }
  end

  # Create default open api definitions and references
  private def register_spoved_defaults
    # Schemas
    register_default_schemas
    # Parameters
    register_default_parameters
    # Responses
    register_default_responses
  end

  # :eq, :gteq, :lteq, :neq, :gt, :lt, :nlt, :ngt, :ltgt, :in, :nin, :like, :nlike
  def filter_params_for_var(name, type, **args) : Array(Open::Api::Parameter)
    params = [] of Open::Api::Parameter
    params << Open::Api::Parameter.new(name, type, **args, description: "return results that match #{name}")

    case Open::Api.get_open_api_type(type)
    when "string"
      Spoved::Kemal::STRING_OPERATORS.each do |op|
        params << Open::Api::Parameter.new(name + "_#{op}", type, **args, description: "return results that are #{op} #{name}")
      end
    when "integer"
      Spoved::Kemal::NUM_OPERATORS.each do |op|
        params << Open::Api::Parameter.new(name + "_#{op}", type, **args, description: "return results that are #{op} #{name}")
      end
    end
    params
  end

  def create_get_list_op_item(model_name, params, resp_ref, operation_id : String? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Returns list of #{model_name}").tap do |op|
      op.operation_id = operation_id.nil? ? "get_#{model_name}_list" : operation_id
      op.tags << model_name
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new("List of #{model_name}").tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: resp_ref),
          }
        end,
      }.merge(default_response_refs)
    end
  end

  def create_get_op_item(model_name, params, resp_ref, operation_id : String? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Returns record of a specified #{model_name}").tap do |op|
      op.operation_id = operation_id.nil? ? "get_#{model_name}_by_id" : operation_id
      op.tags << model_name
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new("#{model_name} record").tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: resp_ref),
          }
        end,
      }.merge(default_response_refs)
    end
  end

  # Create a new delete `Open::Api::OperationItem` for a model
  def create_delete_op_item(model_name, params) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Delete the specified #{model_name}").tap do |op|
      op.operation_id = "delete_#{model_name}_by_id"
      op.tags << model_name
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "204" => SWAGGER_API.response_ref("204"),
      }.merge(default_response_refs)
    end
  end

  # Create a new create `Open::Api::OperationItem` for a model
  def create_put_op_item(model_name, model_ref, body_schema : Open::Api::Schema) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Create new #{model_name} record").tap do |op|
      op.operation_id = "create_#{model_name}"
      op.tags << model_name
      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new("create new #{model_name} record").tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: model_ref),
          }
        end,
      }.merge(default_response_refs)
      op.request_body = Open::Api::RequestBody.new(
        description: "#{model_name} object",
        content: {
          "application/json" => Open::Api::MediaType.new(schema: body_schema),
        },
        required: true,
      )
    end
  end

  def create_patch_op_item(model_name, params, body_object, model_ref) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Update the specified #{model_name}").tap do |op|
      op.operation_id = "update_#{model_name}_by_id"
      op.tags << model_name
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new("update the specified #{model_name}").tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: model_ref),
          }
        end,
      }.merge(default_response_refs)
      op.request_body = Open::Api::RequestBody.new(
        description: "#{model_name} object",
        content: {
          "application/json" => Open::Api::MediaType.new(schema: body_object),
        },
        required: true,
      )
    end
  end
end
