require "../spec_helper"

describe Spoved::ColorizedBackend do
  it "should log" do
    io = IO::Memory.new
    spoved_logger :trace, io, bind: true

    Log.debug { "this is an debug msg" }
    Log.info { "this is an info msg" }
    Log.warn { "this is an warn msg" }
    Log.notice { "this is a notice msg" }
    Log.error { "this is an error msg" }
    Log.fatal { "this is an fatal msg" }
    Log.trace { "this is an trace msg" }

    io.to_s.split(/\n/).size.should eq 8
  end
end
