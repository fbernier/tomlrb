require 'minitest_helper'

describe Tomlrb::Parser do
  it "parses a toml example file" do
    parsed_file = Tomlrb.load_file('./test/example.toml')
    parsed_file.must_equal TomlExamples.example
  end

  it "parses a toml v0.4.0 file" do
    parsed_file = Tomlrb.load_file('./test/example-v0.4.0.toml')
    # FIXME this fails but minitest cannot find a difference in the Hash#inspect output...
    #parsed_file.must_equal TomlExamples.example_v_0_4_0
  end

  it "parses a toml hard file" do
    parsed_file = Tomlrb.load_file('./test/hard_example.toml')
    parsed_file.must_equal TomlExamples.hard_example
  end
end

class TomlExamples
  def self.example_v_0_4_0
    {"table"=>{"key"=>"value", "subtable"=>{"key"=>"another value"}, "inline"=>{"name"=>{"first"=>"Tom", "last"=>"Preston-Werner"}, "point"=>{"x"=>1, "y"=>2}}},
     "x"=>{"y"=>{"z"=>{"w"=>{}}}},
     "string"=>
    {"basic"=>{"basic"=>"I'm a string. \"You can quote me\". Name\tJos\\u00E9\nLocation\tSF."},
     "multiline"=>
    {"key1"=>"One\nTwo",
     "key2"=>"One\nTwo",
     "key3"=>"One\nTwo",
     "continued"=>
    {"key1"=>"The quick brown fox jumps over the lazy dog.",
     "key2"=>"The quick brown fox jumps over the lazy dog.",
     "key3"=>"The quick brown fox jumps over the lazy dog."}},
     "literal"=>
    {"winpath"=>"C:\\Users\\nodejs\\templates",
     "winpath2"=>"\\\\ServerX\\admin$\\system32\\",
     "quoted"=>"Tom \"Dubs\" Preston-Werner",
     "regex"=>"<\\i\\c*\\s*>",
     "multiline"=>{"regex2"=>"I [dw]on't need \\d{2} apples", "lines"=>"The first newline is\ntrimmed in raw strings.\n   All other whitespace\n   is preserved.\n"}}},
    "integer"=>{"key1"=>99, "key2"=>42, "key3"=>0, "key4"=>-17, "underscores"=>{"key1"=>1000, "key2"=>5349221, "key3"=>12345}},
    "float"=>
    {"fractional"=>{"key1"=>1.0, "key2"=>3.1415, "key3"=>-0.01},
     "exponent"=>{"key1"=>5.0e+22, "key2"=>1000000.0, "key3"=>-0.02},
     "both"=>{"key"=>6.626e-34},
     "underscores"=>{"key1"=>9224617.445991227, "key2"=>Float::INFINITY}},
    "boolean"=>{"True"=>true, "False"=>false},
    "datetime"=>{"key1"=>Time.utc(1979, 05, 27, 07, 32, 0), "key2"=>Time.new(1979, 05, 27, 00, 32, 0, '-07:00'), "key3"=>Time.new(1979, 05, 27, 00, 32, 0.999999, '-07:00')}, "array"=>{"key1"=>[1, 2, 3], "key2"=>["red", "yellow", "green"], "key3"=>[[1, 2], [3, 4, 5]], "key4"=>[[1, 2], ["a", "b", "c"]], "key5"=>[1, 2, 3], "key6"=>[1, 2]},
    "products"=>[{"name"=>"Hammer", "sku"=>738594937}, {}, {"name"=>"Nail", "sku"=>284758393, "color"=>"gray"}],
    "fruit"=>
    [{"name"=>"apple", "physical"=>{"color"=>"red", "shape"=>"round"}, "variety"=>[{"name"=>"red delicious"}, {"name"=>"granny smith"}]},
     {"name"=>"banana", "variety"=>[{"name"=>"plantain"}]}]}
  end

  def self.example
    {"title"=>"TOML Example",
     "owner"=>{"name"=>"Tom Preston-Werner", "organization"=>"GitHub", "bio"=>"GitHub Cofounder & CEO\nLikes tater tots and beer.", "dob"=>Time.parse('1979-05-27 07:32:00 UTC')},
     "database"=>{"server"=>"192.168.1.1", "ports"=>[8001, 8001, 8002], "connection_max"=>5000, "enabled"=>true},
     "servers"=>{"alpha"=>{"ip"=>"10.0.0.1", "dc"=>"eqdc10"}, "beta"=>{"ip"=>"10.0.0.2", "dc"=>"eqdc10", "country"=>"中国"}},
     "clients"=>{"data"=>[["gamma", "delta"], [1, 2]], "hosts"=>["alpha", "omega"]},
     "products"=>[{"name"=>"Hammer", "sku"=>738594937}, {"name"=>"Nail", "sku"=>284758393, "color"=>"gray"}]}
  end

  def self.hard_example
    {"the"=>
     {"test_string"=>"You'll hate me after this - #",
      "hard"=>
      {"test_array"=>["] ", " # "],
       "test_array2"=>["Test #11 ]proved that", "Experiment #9 was a success"],
       "another_test_string"=>" Same thing, but with a string #",
       "harder_test_string"=>" And when \"'s are in the string, along with # \"",
       "bit#"=>
      {"what?"=>"You don't think some user won't do that?",
       "multi_line_array"=>["]"]}}}}
  end
end
