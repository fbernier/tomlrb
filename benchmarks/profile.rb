#!/usr/bin/env ruby
begin
  require "ruby-prof"
rescue LoadError
  abort("Install ruby-prof using 'gem install ruby-prof' first.")
end

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "tomlrb"

data = File.read(File.join(__dir__, "../test/example-v0.4.0.toml"))

profile = RubyProf::Profile.profile do
  1000.times { Tomlrb.parse(data) }
end

RubyProf::FlatPrinter.new(profile).print($stdout)
