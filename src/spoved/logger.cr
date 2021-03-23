require "log"
require "colorize"

macro spoved_bind_logger(level = :debug, io = STDOUT, name = "*", dispatcher = :async)
  {% if io.id == "STDOUT" %}
    ::Log.builder.bind(
      source: {{name}},
      level: ::Log::Severity::{{level.capitalize.id}},
      backend: Spoved::ColorizedBackend.new( {{io}}, dispatcher: {{dispatcher}} ),
    )
  {% else %}
    ::Log.builder.bind(
      source: {{name}},
      level: ::Log::Severity::{{level.capitalize.id}},
      backend: ::Log::IOBackend.new( {{io}}, dispatcher: {{dispatcher}} ),
    )
  {% end %}
end

macro spoved_logger(level = :debug, io = STDOUT, bind = false, clear = false, dispatcher = :async)
  {% if clear %}
    Log.builder.clear
  {% end %}

  {% if @type.id == "main" %}
    {% if bind %}
      spoved_bind_logger({{level}}, {{io}}, dispatcher: {{dispatcher}})
    {% end %}
  {% else %}

    {% if bind %}
      spoved_bind_logger({{level}}, {{io}}, {{@type.id}}.name.underscore.gsub("::", "."), dispatcher: {{dispatcher}})
    {% end %}

    @@logger = ::Log.for({{@type.id}})

    def logger
      @@logger
    end

    def self.logger
      @@logger
    end

  {% end %} # end if @type.id == "main"
end

module Spoved
  Log = ::Log.for(self)

  ::Log.define_formatter ::Spoved::ColorizedFormat,
    "#{timestamp} #{severity} - #{source(after: ": ")}#{message}" \
    "#{data(before: " -- ")}#{context(before: " -- ")}#{exception}"

  module ColorizeHelper
    def get_color(severity)
      case severity
      when ::Log::Severity::Trace
        :cyan
      when ::Log::Severity::Debug
        :blue
      when ::Log::Severity::Info
        :green
      when ::Log::Severity::Notice
        :magenta
      when ::Log::Severity::Warn
        :yellow
      when ::Log::Severity::Error
        :light_red
      when ::Log::Severity::Fatal
        :red
      else
        :default
      end
    end

    def format(entry, io)
      Colorize.with.colorize(get_color(entry.severity)).surround(io) do
        new(entry, io).run
      end
    end
  end

  struct ColorizedFormat < ::Log::StaticFormatter
    extend ColorizeHelper
  end

  class ColorizedBackend < ::Log::IOBackend
    def initialize(@io = STDOUT, dispatch_mode = :async)
      @dispatcher = ::Log::Dispatcher.for(dispatch_mode)
      @mutex = Mutex.new(:unchecked)
      @progname = File.basename(PROGRAM_NAME)
      @formatter = ColorizedFormat
    end
  end
end
