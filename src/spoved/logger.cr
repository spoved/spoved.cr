require "logger"
require "colorize"

macro spoved_logger
  def logger
    Spoved.logger
  end

  def logger=(value : ::Logger)
    Spoved.logger = value
  end

  def self.logger
    Spoved.logger
  end

  def self.logger=(value : ::Logger)
    Spoved.logger = value
  end
end

module Spoved
  class Logger < ::Logger
    private SPOVED_FORMATTER = Formatter.new do |severity, datetime, progname, message, io|
      label = severity.unknown? ? "ANY" : severity.to_s

      with_color.colorize(Spoved::Logger.get_color(severity)).surround(io) do
        io << label[0] << ", [" << datetime << " #" << Process.pid << "] "
        io << label.rjust(5) << " -- " << progname << ": " << message
      end
    end

    # Creates a new logger that will log to the given *io*.
    # If *io* is `nil` then all log calls will be silently ignored.
    def initialize(@io : IO?, @level = Severity::INFO, @formatter = SPOVED_FORMATTER, @progname = "")
      @closed = false
      @mutex = Mutex.new
    end

    def self.get_color(severity)
      case severity
      when ::Logger::DEBUG
        :cyan
      when ::Logger::INFO
        :magenta
      when ::Logger::WARN
        :yellow
      when ERROR
        :red
      when ::Logger::FATAL
        :light_red
      when ::Logger::UNKNOWN
        :light_gray
      else
        :default
      end
    end

    private def write(severity, datetime, progname, message)
      io = @io
      return unless io

      progname_to_s = progname.to_s
      message_to_s = message.to_s

      @mutex.synchronize do
        formatter.call(severity, datetime, progname_to_s, message_to_s, io)
        io.puts
        io.flush
      end
    end
  end

  @@logger : ::Logger = Spoved::Logger.new(STDOUT)

  def self.logger
    @@logger
  end

  def self.logger=(value : ::Logger)
    @@logger = value
  end
end
