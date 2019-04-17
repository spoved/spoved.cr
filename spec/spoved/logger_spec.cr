require "../spec_helper"

class TestLogger
  spoved_logger
end

describe Spoved::Logger do
  it "should log" do
    io = IO::Memory.new
    logger = Spoved::Logger.new(io)
    logger.level = Logger::DEBUG

    logger.debug("this is an debug msg")
    logger.info("this is an info msg")
    logger.warn("this is an warn msg")
    logger.error("this is an error msg")
    logger.fatal("this is an fatal msg")
    logger.unknown("this is an unknown msg")

    io.to_s.split(/\n/).size.should eq 7
  end

  it "should add logger to class" do
    TestLogger.logger.should be_a(Spoved::Logger)
    obj = TestLogger.new
    obj.logger.should be_a(Spoved::Logger)
  end
end
