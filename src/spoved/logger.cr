require "log"
require "colorize"

macro spoved_logger(level = :debug, io = STDOUT, bind = false)
  {% if @type.id == "main" %}
    {% if bind %}
      {% if io.id == "STDOUT" %}
        ::Log.builder.bind("*", {{level}}, Spoved::ColorizedBackend.new({{io}}))
      {% else %}
        ::Log.builder.bind("*", {{level}}, Log::IOBackend.new({{io}}))
      {% end %}
    {% end %}
  {% else %}

    {% if bind %}
      {% if io.id == "STDOUT" %}
        ::Log.builder.bind({{@type.id}}.name.underscore.gsub("::", "."), {{level}}, Spoved::ColorizedBackend.new({{io}}) )
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

  struct ColorizedFormat < ::Log::StaticFormatter
    # def run
    #   color = ::Spoved::ColorizedFormat.get_color(severity)
    #   Colorize.with.colorize(color).surround(@io) do
    #     super.run
    #   end
    # end

    def self.format(entry, io)
      color = ::Spoved::ColorizedFormat.get_color(entry.severity)
      Colorize.with.colorize(color).surround(io) do
        new(entry, io).run
      end
    end

    def self.get_color(severity)
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
  end

  class ColorizedBackend < ::Log::IOBackend
    def initialize(@io = STDOUT)
      @mutex = Mutex.new(:unchecked)
      @progname = File.basename(PROGRAM_NAME)
      @formatter = ColorizedFormat
    end
  end
end
