# spoved

[![build](https://github.com/spoved/spoved.cr/actions/workflows/build.yml/badge.svg)](https://github.com/spoved/spoved.cr/actions/workflows/build.yml)

<p align="center">
    <a href="https://github.com/spoved/spoved.cr/actions/workflows/build.yml">
        <img src="https://github.com/spoved/spoved.cr/actions/workflows/build.yml/badge.svg" alt="Build Status"></a>
    <a href="https://github.com/spoved/spoved.cr/actions/workflows/release.yml">
        <img src="https://github.com/spoved/spoved.cr/actions/workflows/release.yml/badge.svg" alt="Release Status"></a>
    <a href="https://github.com/spoved/spoved.cr/releases">
        <img src="https://img.shields.io/github/v/release/spoved/spoved.cr" alt="Latest release"></a>
</p>

This repository contains shared tools and libraries to help development of crystal libraries easier.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     spoved:
       github: spoved/spoved.cr
   ```

2. Run `shards install`

## Usage

### Spoved::Logger

You can use the `spoved_logger` to automatically add the logger methods to any class:

```crystal
require "spoved/logger"

class TestObj
  spoved_logger
end

obj = TestObj.new
obj.logger.debug { "I can log a debug in color now" }
```

This also adds a class/module level logger:

```crystal
require "spoved/logger"

module TestModule
  spoved_logger
end

TestModule.logger.debug { "I can log a module debug now" }
```

Without the `bind: true` argument it will only create the class/instance methods. When bind is `true` it will call `::Log.builder.bind` and register the IO (`STDOUT` by default) and `Spoved::ColorizedBackend` as the backend.

```crystal
require "spoved/logger"

spoved_logger(bind: true)

Log.debug { "this is an debug msg" }
Log.info { "this is an info msg" }
Log.warn { "this is an warn msg" }
Log.error { "this is an error msg" }
Log.fatal { "this is an fatal msg" }
Log.unknown { "this is an unknown msg" }
```

Full example:

```crystal
require "spoved/logger"

module TestModule
  spoved_logger level: :debug, io: STDOUT, bind: true
end

TestModule.logger.debug { "I can log a module debug now" }
```

### Spoved::Api::Client

The `Spoved::Api::Client` also provides an abstraction wrapper for Halite to make creation of basic api clients easier.

```crystal
require "spoved/api/client"

client = Spoved::Api::Client.new("jsonplaceholder.typicode.com", scheme: "https", api_path: "")
client.should_not be_nil
resp = client.get("todos/1")
resp["title"] # => "delectus aut autem"
```

You can also extend it to simplify creation of api clients:

```crystal
require "spoved/api/client"

class TodoClient < Spoved::Api::Client
  def initialize
    @host = "jsonplaceholder.typicode.com"
  end

  def todo(id)
    client.get("todos/#{id}")
  end
end

client = TodoClient.new
client.todo(1)["title"] # => "delectus aut autem"
```

### Spoved::Cli

This is a semi-useful wrapper for the [commander](https://github.com/mrrooijen/commander) cli util.

First create your main cli class which should inherit from `Spoved::Cli::Main`:

```crystal
require "spoved/cli"

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
```

You can then add sub commands via annotations to other classes:

```crystal
@[Spoved::Cli::SubCommand(name: :do_it, descr: "do something")]
class DoItCmd
  @[Spoved::Cli::Command(name: :now, descr: "do it now")]
  def now(cmd, options, arguments)
    puts "doing it now!!!"
  end

  @[Spoved::Cli::Command(name: :later, descr: "do it now")]
  def later(cmd, options, arguments)
    puts "doing it later..."
  end
end

@[Spoved::Cli::Command(name: :dont, descr: "dont do it")]
class DontDoIt
  def run(cmd, options, arguments)
    puts "I WONT DO IT!"
  end
end
```

Finally you need to add the run to wherever your app entrypoint is:

```crystal
MyCli::Main.run(ARGV)
```

#### Adding flags

You can add new flags by defining them in the `flags` argument in the annotations:

```crystal
  @[Spoved::Cli::Command(name: :daemon, descr: "run daemon", flags: [
    {
      name:        "workers",
      short:       "-w",
      long:        "--workers",
      description: "Number of worker fibers",
      default:     1,
      persistent:  true,
    },
  ])]
```

The `opts` argument can also be used to shortcut and reuse pre-defined macros that meet the following format (also see [arg_macros.cr](src/spoved/cli/arg_macros.cr) for common ones):

```crystal
# macro to be used with opts argument. arg name is defined by: opt_XXXX. Provide XXXX as a symbol to array.
macro opt_id(c)
  {{c}}.flags.add do |flag|
    flag.name = "id"
    flag.short = "-i"
    flag.long = "--id"
    flag.default = ""
    flag.description = "id of element"
  end
end
```

This macro can then be used:

```crystal
@[Spoved::Cli::SubCommand(name: :do_it, descr: "do something")]
class DoItCmd
  @[Spoved::Cli::Command(name: :now, descr: "do it now", opts: [:id])]
  def now(cmd, options, arguments)
    puts "doing it now!!!"
  end

  @[Spoved::Cli::Command(name: :later, descr: "do it later", opts: [:id])]
  def later(cmd, options, arguments)
    puts "doing it later..."
  end
end
```

## Contributing

1. Fork it (<https://github.com/spoved/spoved.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Holden Omans](https://github.com/kalinon) - creator and maintainer
