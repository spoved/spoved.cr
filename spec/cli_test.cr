require "./src/spoved/cli"

class MyCli::Main < Spoved::Cli::Main
  def config(cmd : Commander::Command)
    cmd.use = "my-cli"
    cmd.long = "this is my awesome cli tool"
  end

  # Can override the default run here
  def run(cmd, options, arguments)
    puts cmd.help # => Render help screen
  end
end

@[Spoved::Cli::SubCommand(name: :do_it, descr: "do something")]
class DoItCmd
  @[Spoved::Cli::Command(name: :now, descr: "do it now")]
  def now(cmd, options, arguments)
    puts "doing it now!!!"
  end

  @[Spoved::Cli::Command(name: :later, descr: "do it later")]
  def later(cmd, options, arguments)
    puts "doing it later..."
  end
end

@[Spoved::Cli::Command(name: :dont, descr: "dont do it")]
class DontDoIt
  # @[Spoved::Cli::Command(name: :dont, descr: "dont do it")]
  def run(cmd, options, arguments)
    puts "I WONT DO IT!"
  end
end

MyCli::Main.run(ARGV)
