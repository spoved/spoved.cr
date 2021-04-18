require "../logger"
require "kemal"

class Spoved::Kemal::Logger < ::Kemal::BaseLogHandler
  spoved_logger

  # This is run for each request. You can access the request/response context with `context`.
  def call(context)
    elapsed_time = Time.measure { call_next(context) }
    elapsed_text = elapsed_text(elapsed_time)
    logger.info {
      String::Builder.build do |builder|
        builder << context.response.status_code << ' ' << context.request.method << ' ' << context.request.resource << ' ' << elapsed_text
      end
    }

    context
  end

  def write(message)
    logger.info { message.chomp }
  end

  private def elapsed_text(elapsed)
    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1

    "#{(millis * 1000).round(2)}µs"
  end
end
