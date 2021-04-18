module Spoved::Cli::Commands; end

# This annotion defines a command that will execute the function it annotates or the method `run`
#
# Example of a class with a `run` method defined
# ```
# @[Spoved::Cli::Command(name: :dont, descr: "dont do it")]
# class DontDoIt
#   def run(cmd, options, arguments)
#     puts "I WONT DO IT!"
#   end
# end
# ```
#
# Example specifying a specific method to execute
# ```
# @[Spoved::Cli::SubCommand(name: :do_it, descr: "do something")]
# class DoItCmd
#   @[Spoved::Cli::Command(name: :now, descr: "do it now")]
#   def now(cmd, options, arguments)
#     puts "doing it now!!!"
#   end

#   @[Spoved::Cli::Command(name: :later, descr: "do it now")]
#   def later(cmd, options, arguments)
#     puts "doing it later..."
#   end
# end
# ```
annotation Spoved::Cli::Command; end

# This annotion defines a sub command that allows nesting
#
# ```
# @[Spoved::Cli::SubCommand(name: :server, descr: "start server")]
# class Server
# end
# ```
# This command would be available at `./bin/mycli server`
annotation Spoved::Cli::SubCommand; end

annotation Spoved::Cli::PreRun; end

require "./cli/logging"
require "./cli/macros"

macro cmd_error_help(msg = "")
  {% if !msg.empty? %}
  Log.error { {{msg}} }
  {% end %}

  puts cmd.help
  exit 1
end

require "./cli/main"
