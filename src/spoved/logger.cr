require "log"
require "colorize"

macro spoved_logger(level = :debug, io = STDOUT, bind = false)
  {% if @type.id == "main" %}
    {% if bind %}
      {% if io.id == "STDOUT" %}
        {% if flag?(:preview_mt) %}
          ::Log.builder.bind("*", {{level}}, Spoved::ColorizedBackendMT.new({{io}}))
        {% else %}
          ::Log.builder.bind("*", {{level}}, Spoved::ColorizedBackend.new({{io}}))
        {% end %}
      {% else %}
        ::Log.builder.bind("*", {{level}}, Log::IOBackend.new({{io}}))
      {% end %}
    {% end %}
  {% else %}

    {% if bind %}
      {% if io.id == "STDOUT" %}

        {% if flag?(:preview_mt) %}
          ::Log.builder.bind({{@type.id}}.name.underscore.gsub("::", "."), {{level}}, Spoved::ColorizedBackendMT.new({{io}}) )
        {% else %}
          ::Log.builder.bind({{@type.id}}.name.underscore.gsub("::", "."), {{level}}, Spoved::ColorizedBackend.new({{io}}) )
        {% end %}

      {% else %}
        ::Log.builder.bind({{@type.id}}.name.underscore.gsub("::", "."), {{level}}, Log::IOBackend.new({{io}}))
      {% end %}
    {% end %}

  @@logger = ::Log.for( {{@type.id}} )

  def logger
    @@logger
  end

  def self.logger
    @@logger
  end

  {% end %}
end

module Spoved
  Log = ::Log.for(self)

  ::Log.define_formatter ::Spoved::ColorizedFormat, "#{timestamp} #{severity} - #{source(after: ": ")}#{message}" \
                                                    "#{data(before: " -- ")}#{context(before: " -- ")}#{exception}"

  ::Log.define_formatter ::Spoved::ColorizedFormatMT, "#{timestamp} #{severity} - #{source(after: ": ")}[#{Fiber.current.name}] #{message}" \
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

  struct ColorizedFormatMT < ::Log::StaticFormatter
    extend ColorizeHelper
  end

  class ColorizedBackend < ::Log::IOBackend
    def initialize(@io = STDOUT)
      @mutex = Mutex.new(:unchecked)
      @progname = File.basename(PROGRAM_NAME)
      @formatter = ColorizedFormat
    end
  end

  class ColorizedBackendMT < ::Log::IOBackend
    def initialize(@io = STDOUT)
      @mutex = Mutex.new(:unchecked)
      @progname = File.basename(PROGRAM_NAME)
      @formatter = ColorizedFormatMT
    end
  end
end
