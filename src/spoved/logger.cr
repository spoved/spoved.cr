require "log"
require "colorize"
require "../spoved"

macro spoved_bind_logger(level = :debug, io = STDOUT, name = "*", dispatcher = :async, color = true)
  {% if io.id == "STDOUT" && color %}
    ::Log.builder.bind(
      source: {{name}},
      level: ::Log::Severity::{{level.capitalize.id}},
      backend: Spoved::ColorizedBackend.new( {{io}}, dispatch_mode: {{dispatcher}} ),
    )
  {% else %}
    ::Log.builder.bind(
      source: {{name}},
      level: ::Log::Severity::{{level.capitalize.id}},
      backend: ::Log::IOBackend.new( {{io}}, dispatcher: {{dispatcher}} ),
    )
  {% end %}
end

macro spoved_logger(level = :debug, io = STDOUT, bind = false, clear = false, dispatcher = :async, color = true)
  {% if clear %}
    Log.builder.clear
  {% end %}

  {% if @type.id == "main" %}
    {% if bind %}
      spoved_bind_logger({{level}}, {{io}}, dispatcher: {{dispatcher}}, color: {{color}})
    {% end %}
  {% else %}

    {% if bind %}
      spoved_bind_logger({{level}}, {{io}}, {{@type.name.id}}.name.underscore.gsub("::", "."), dispatcher: {{dispatcher}}, color: {{color}})
    {% end %}

    @@logger = ::Log.for({{@type.name.id}})

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
      mode = case dispatch_mode
             when :async
               ::Log::DispatchMode::Async
             when :sync
               ::Log::DispatchMode::Sync
             when :direct
               ::Log::DispatchMode::Direct
             else
               ::Log::DispatchMode::Async
             end

      @dispatcher = ::Log::Dispatcher.for(mode)
      @mutex = Mutex.new(:unchecked)
      @progname = File.basename(PROGRAM_NAME)
      @formatter = ColorizedFormat
    end
  end
end
