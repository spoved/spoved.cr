require "log"
require "colorize"

macro spoved_bind_logger(level = :debug, io = STDOUT, name = "*")
  {% if io.id == "STDOUT" %}
    ::Log.builder.bind({{name}}, {{level}}, Spoved::ColorizedBackend.new({{io}}) )
  {% else %}
    ::Log.builder.bind({{name}}, {{level}}, Log::IOBackend.new({{io}}))
  {% end %}
end

macro spoved_logger(level = :debug, io = STDOUT, bind = false, clear = false)
  {% if clear %}
    Log.builder.clear
  {% end %}

  {% if @type.id == "main" %}
    {% if bind %}
      spoved_bind_logger {{level}}, {{io}}
    {% end %}
  {% else %}

    {% if bind %}
      spoved_bind_logger {{level}}, {{io}}, {{@type.id}}.name.underscore.gsub("::", ".")
    {% end %}

    @@logger = ::Log.for( {{@type.id}} )

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

  ::Log.define_formatter ::Spoved::ColorizedFormat, "#{timestamp} #{severity} - #{source(after: ": ")}#{message}" \
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
    def initialize(@io = STDOUT)
      @mutex = Mutex.new(:unchecked)
      @progname = File.basename(PROGRAM_NAME)
      @formatter = ColorizedFormat
    end
  end
end
