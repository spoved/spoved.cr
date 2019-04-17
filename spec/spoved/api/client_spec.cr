require "../../spec_helper"

describe Spoved::Api::Client do
  it "should perform a get request" do
    client = Spoved::Api::Client.new("jsonplaceholder.typicode.com", scheme: "https", api_path: "")
    client.should_not be_nil
    resp = client.get("todos/1")
    resp.should be_a(JSON::Any)
    resp["title"].should eq "delectus aut autem"
  end
end
