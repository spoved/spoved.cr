require "../logger"
require "commander"

module Spoved::Cli
  spoved_logger

  def logging(cmd)
    cmd.flags.add do |flag|
      flag.name = "verbose"
      flag.short = "-v"
      flag.long = "--verbose"
      flag.default = false
      flag.description = "Enable more verbose logging."
      flag.persistent = true
    end

    cmd.flags.add do |flag|
      flag.name = "debug"
      flag.short = "-d"
      flag.long = "--debug"
      flag.default = false
      flag.description = "Enable debug logging."
      flag.persistent = true
    end

    cmd.flags.add do |flag|
      flag.name = "silent"
      flag.short = "-s"
      flag.long = "--silent"
      flag.default = false
      flag.description = "Set logging to minium (error only)."
      flag.persistent = true
    end

    cmd.flags.add do |flag|
      flag.name = "log_file"
      flag.long = "--log-file"
      flag.default = ""
      flag.description = "File to save log output."
      flag.persistent = true
    end
  end

  def setup_logging(options)
    level = if options.bool["silent"]
              ::Log::Severity::Error
            elsif options.bool["verbose"]
              ::Log::Severity::Trace
            elsif options.bool["debug"]
              ::Log::Severity::Debug
            else
              ::Log::Severity::Info
            end

    ::Log.builder.clear

    if options.string["log_file"].empty?
      ::Log.builder.bind(
        source: "*",
        level: level,
        backend: ::Spoved::ColorizedBackend.new(STDOUT, dispatch_mode: :sync)
      )
    else
      ::Log.builder.bind(
        source: "*",
        level: level,
        backend: ::Log::IOBackend.new(File.open(options.string["log_file"], "a"), dispatcher: :sync),
      )
    end
  end
end
