require "../spoved"

# Module to provide helpers for runnins system commands
module Spoved::SystemCmd
  # Will execute the provided command and return true/false if it fails.
  # The command output will also be logged
  def system_cmd?(command : String, args = nil, env : Process::Env = nil, clear_env : Bool = false, shell : Bool = false)
    system_cmd(command, args, env, clear_env, shell)[:status]
  end

  def system_cmd(command : String, args : Array(String)? = nil, env : Process::Env = nil, clear_env : Bool = false, shell : Bool = true)
    if args
      logger.debug { "Running command : #{command} #{args.join(" ")}" }
    else
      logger.debug { "Running command : #{command}" }
    end

    process = Process.new(
      command,
      args,
      env,
      clear_env,
      shell: shell,
      input: Process::Redirect::Inherit,
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Pipe
    )

    output = process.output.gets_to_end
    error = process.error.gets_to_end
    status = process.wait

    result = {
      output: output,
      error:  error,
      status: status.success?,
    }

    if result[:status]
      logger.debug { result[:output].chomp } unless result[:output].chomp.empty?
      logger.error { result[:error].chomp } unless result[:error].chomp.empty?
    else
      logger.debug { result[:output].chomp } unless result[:output].chomp.empty?
      logger.error { result[:error].chomp } unless result[:error].chomp.empty?
    end

    result
  end
end
