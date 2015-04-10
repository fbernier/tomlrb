require 'minitest_helper'

describe Tomlrb::Parser do
  it "parses a toml v0.4.0 file" do
    parsed_file = Tomlrb.load_file('./test/example-v0.4.0.toml')
  end
end
