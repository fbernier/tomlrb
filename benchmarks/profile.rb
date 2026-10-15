#!/usr/bin/env ruby
# frozen_string_literal: true

# Samples Tomlrb.parse with Vernier (`gem install vernier`) and writes a profile
# for https://vernier.prof or the Firefox Profiler.
#
#   ruby benchmarks/profile.rb [file.toml] [iterations]

begin
  require "vernier"
rescue LoadError
  abort("Install vernier using 'gem install vernier' first.")
end
require "tmpdir"
require_relative "../lib/tomlrb"

data = File.read(ARGV.fetch(0, File.join(__dir__, "example.toml")))
iterations = Integer(ARGV.fetch(1, "2000"))
out = File.join(Dir.tmpdir, "tomlrb-profile.json")

Vernier.profile(out: out, interval: 100) { iterations.times { Tomlrb.parse(data) } }
puts "Profile written to #{out}"
