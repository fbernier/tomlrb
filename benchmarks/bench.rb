#!/usr/bin/env ruby
# frozen_string_literal: true

# Compares Tomlrb.parse with other parsers that are installed. One iteration
# parses every given file, so a corpus can be passed as a glob.
#
#   ruby benchmarks/bench.rb [file.toml...]

require "benchmark/ips"
require_relative "../lib/tomlrb"

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

files = ARGV.empty? ? [File.join(__dir__, "../test/example-v0.4.0.toml")] : ARGV
docs = files.map { |file| File.read(file) }

Benchmark.ips do |x|
  others.each do |name, (_, parser)|
    klass = parser.call
    x.report(name) { docs.each { |doc| klass.parse(doc) } }
  end

  x.report("fbernier/tomlrb") do
    docs.each { |doc| Tomlrb.parse(doc) }
  end

  x.compare!
end
