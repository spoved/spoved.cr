require "../../spec_helper"

class TestClient < Spoved::Api::Client
end

describe Spoved::Api::Client do
  it "should perform a get request" do
    client = TestClient.new("jsonplaceholder.typicode.com", scheme: "https", api_path: "")
    client.should_not be_nil
    resp = client.get("todos/1")
    resp.should be_a(JSON::Any)
    resp["title"].should eq "delectus aut autem"
  end

  it "should perform a request with timeout" do
    client = TestClient.new("jsonplaceholder.typicode.com", scheme: "https", api_path: "", read_timeout: 120)
    client.should_not be_nil
    resp = client.get("todos/1")
    resp.should be_a(JSON::Any)
    resp["title"].should eq "delectus aut autem"
  end

  it "should pass extra headers" do
    client = TestClient.new("jsonplaceholder.typicode.com", scheme: "https", api_path: "", read_timeout: 120)
    client.should_not be_nil
    resp = client.get("todos/1", extra_headers: {"Stuff" => "value"})
    resp.should be_a(JSON::Any)
    resp["title"].should eq "delectus aut autem"
  end
end
