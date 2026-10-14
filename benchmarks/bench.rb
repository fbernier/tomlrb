#!/usr/bin/env ruby
require "benchmark/ips"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "tomlrb"

# Other parsers are compared when installed (`gem install toml-rb perfect_toml`).
others = {
  "emancu/toml-rb" => ["toml-rb", -> { TomlRB }],
  "mame/perfect_toml" => ["perfect_toml", -> { PerfectTOML }]
}.select do |name, (feature, _)|
  require feature
  true
rescue LoadError
  warn("Skipping #{name}: gem install #{feature}")
  false
end

data = File.read(ARGV.fetch(0, File.join(__dir__, "../test/example-v0.4.0.toml")))

Benchmark.ips do |x|
  others.each do |name, (_, parser)|
    klass = parser.call
    x.report(name) { klass.parse(data) }
  end

  x.report("fbernier/tomlrb") do
    Tomlrb.parse(data)
  end

  x.compare!
end
