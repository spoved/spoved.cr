module Spoved::Cli::Commands; end

annotation Spoved::Cli::Command; end
annotation Spoved::Cli::SubCommand; end
annotation Spoved::Cli::PreRun; end

require "./cli/logging"
require "./cli/macros"

abstract class Spoved::Cli::Main
  include Spoved::Cli

  abstract def config(cmd : Commander::Command)

  def _config
    Commander::Command.new do |cmd|
      logging(cmd)
      config(cmd)

      register_cli_commands

      cmd.run do |options, arguments|
        setup_cli(options, arguments)
        run(cmd, options, arguments)
      end
    end
  end

  def run(cmd, options, arguments)
    puts cmd.help # => Render help screen
  end

  def self.run(argv)
    self.new.run(argv)
  end

  def run(argv)
    Commander.run(_config, argv)
  end
end

macro cmd_error_help(msg = "")
  {% if !msg.empty? %}
  Log.error { {{msg}} }
  {% end %}

  puts cmd.help
  exit 1
end
