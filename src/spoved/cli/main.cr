abstract class Spoved::Cli::Main
  include Spoved::Cli

  macro inherited
    spoved_logger
  end

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
