module Spoved::Kemal
  extend self

  def not_found_resp(env, msg)
    env.response.status_code = 404
    env.response.content_type = "application/json"
    env.response.print(set_content_length({code: 404, message: msg}.to_json, env))
    env.response.close
  end

  def resp_204(env)
    env.response.status_code = 204
    env.response.close
  end

  def set_content_length(resp, env)
    resp = "{}" if resp.nil?
    env.response.content_length = resp.bytesize
    resp
  end

  def response_data(limit, offset, data, total)
    {
      limit:  limit,
      offset: offset,
      size:   data.size,
      total:  total,
      data:   data,
    }
  end

  def limit_offset_args(env)
    limit = env.params.query["limit"]?.nil? ? DEFAULT_LIMIT : env.params.query["limit"].to_i
    offset = env.params.query["offset"]?.nil? ? 0 : env.params.query["offset"].to_i

    {limit, offset}
  end

  def order_by_args(env)
    order_by = env.params.query["order_by"]?.nil? ? nil : env.params.query["order_by"]
    if order_by.nil?
      Array(String).new
    else
      order_by.split(',')
    end
  end
end
