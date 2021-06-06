require "../spec_helper"
require "log/spec"

struct Logaroo
  spoved_logger :trace, bind: true, dispatcher: :sync

  def make_logs
    Log.trace { "this is an trace msg" }
    Log.debug { "this is an debug msg" }
    Log.info { "this is an info msg" }
    Log.notice { "this is a notice msg" }
    Log.warn { "this is an warn msg" }
    Log.error { "this is an error msg" }
    Log.fatal { "this is an fatal msg" }
  end
end

describe Spoved::ColorizedBackend do
  it "should log" do
    obj = Logaroo.new
    Log.capture do |logs|
      obj.make_logs

      logs.next(:trace, /trace/i)
      logs.next(:debug, /debug/i)
      logs.next(:info, /info/i)
      logs.next(:notice, /notice/i)
      logs.next(:warn, /warn/i)
      logs.next(:error, /error/i)
      logs.next(:fatal, /fatal/i)
    end
  end
end
