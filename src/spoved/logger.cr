require "log"
require "colorize"

macro spoved_logger(level = :debug, io = STDOUT)
  {% if @type.id == "main" %}
    {% if io.id == "STDOUT" %}
      ::Log.builder.bind("*", {{level}}, Spoved::ColorizedBackend.new({{io}}))
    {% else %}
      ::Log.builder.bind("*", {{level}}, Log::IOBackend.new({{io}}))
    {% end %}
  {% else %}


    {% if io.id == "STDOUT" %}
      ::Log.builder.bind({{@type.id}}.name.underscore.gsub("::", "."), {{level}}, Spoved::ColorizedBackend.new({{io}}) )
    {% else %}
      ::Log.builder.bind({{@type.id}}.name.underscore.gsub("::", "."), {{level}}, Log::IOBackend.new({{io}}))
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

  class ColorizedBackend < ::Log::IOBackend
    private def formater(entry : ::Log::Entry, io : IO)
      color = ::Spoved::ColorizedBackend.get_color(entry.severity)
      Colorize.with.colorize(color).surround(io) do
        default_format(entry)
      end
    end

    def initialize(@io = STDOUT)
      @mutex = Mutex.new(:unchecked)
      @progname = File.basename(PROGRAM_NAME)
      @formatter = ->formater(::Log::Entry, IO)
    end

    def self.get_color(severity)
      case severity
      when ::Log::Severity::Debug
        :cyan
      when ::Log::Severity::Info
        :magenta
      when ::Log::Severity::Warning
        :yellow
      when ::Log::Severity::Error
        :red
      when ::Log::Severity::Fatal
        :light_red
      when ::Log::Severity::Verbose
        :light_gray
      else
        :default
      end
    end
  end
end
