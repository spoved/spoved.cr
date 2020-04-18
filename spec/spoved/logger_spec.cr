require "../spec_helper"

describe Spoved::ColorizedBackend do
  it "should log" do
    io = IO::Memory.new
    spoved_logger :debug, io

    Log.debug { "this is an debug msg" }
    Log.info { "this is an info msg" }
    Log.warn { "this is an warn msg" }
    Log.error { "this is an error msg" }
    Log.fatal { "this is an fatal msg" }
    Log.verbose { "this is an verbose msg" }

    io.to_s.split(/\n/).size.should eq 7
  end
end
