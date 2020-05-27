# spoved

[![Build Status](https://travis-ci.com/spoved/spoved.cr.svg?branch=master)](https://travis-ci.com/spoved/spoved.cr)

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

## Contributing

1. Fork it (<https://github.com/spoved/spoved.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Holden Omans](https://github.com/kalinon) - creator and maintainer
