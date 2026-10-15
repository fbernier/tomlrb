#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures one parser over a matrix of generated workloads, one per input shape
# a change can speed up or slow down: per-parse time, Ruby allocations, peak RSS
# growth (native memory included) and a digest of the parse results.
#
#   ruby [--yjit] benchmarks/matrix.rb [--parser tomlrb|perfect_toml] [--lib DIR] [--unknown-coderange] [WORKLOAD...]
#
# Inputs are generated from a fixed seed, so runs are comparable across commits.
# `--lib` loads tomlrb from another checkout's lib/ (e.g. a `git worktree` of the
# previous commit); equal digests mean both versions parsed every workload alike.
# Each timed parse gets a fresh String object holding its input. Like a string
# from File.read, that copy keeps a known code range, so the parser's UTF-8
# validation is a cached lookup; `--unknown-coderange` builds copies whose code
# range is unknown, which makes each parse pay for the full validation scan.

require "digest"
require "optparse"
require "rbconfig"

options = {parser: "tomlrb", lib: File.expand_path("../lib", __dir__)}
OptionParser.new do |o|
  o.banner = "Usage: ruby [--yjit] benchmarks/matrix.rb [options] [WORKLOAD...]"
  o.on("--parser NAME", %w[tomlrb perfect_toml], "tomlrb (default) or perfect_toml") { options[:parser] = _1 }
  o.on("--lib DIR", "load tomlrb from DIR") { options[:lib] = File.expand_path(_1) }
  o.on("--unknown-coderange", "time UTF-8 validation too (see above)") { options[:unknown_coderange] = true }
  o.on("--rss-child NAME") { options[:rss_child] = _1 } # internal: one workload's peak RSS
end.parse!

parse =
  if options[:parser] == "tomlrb"
    $LOAD_PATH.unshift(options[:lib])
    require "tomlrb"
    ->(doc) { Tomlrb.parse(doc) }
  else
    require "perfect_toml"
    ->(doc) { PerfectTOML.parse(doc) }
  end

rng = Random.new(42)
words = %w[alpha beta gamma delta epsilon parser value quick brown fox jumps over lazy dog 0.1.0]
text = ->(bytes) do
  out = +""
  out << words.sample(random: rng) << " " while out.bytesize < bytes
  out.strip
end
lines = ->(bytes) do
  out = +""
  out << text.call(70) << "\n" while out.bytesize < bytes
  out
end
test_file = ->(name) { File.read(File.join(__dir__, "../test", name)) }

# Each workload is a list of documents; one "parse" parses all of them.
WORKLOADS = {
  "example" => [File.read(File.join(__dir__, "example.toml"))],
  "cargo_toml" => [test_file.call("Cargo.toml")],
  "small_docs" => Array.new(500) { |i| %(name = "doc#{i}"\nversion = #{i}\n\n[meta]\nok = true\n) },
  "plain_strings" => [Array.new(1000) { |i| %(k#{i} = "#{text.call(60)}"\n) }.join],
  "escaped_strings" => [Array.new(1000) { |i| %(k#{i} = "a\\tb\\n\\"q\\" \\u00e9 #{text.call(30)}"\n) }.join],
  "string_1mb" => [%(s = "#{text.call(1 << 20)}"\n)],
  "multiline_4kb" => [%(s = """\n#{lines.call(4 << 10)}"""\n)],
  "multiline_1mb" => [%(s = """\n#{lines.call(1 << 20)}"""\n)],
  "literal_1mb" => [%(s = '#{text.call(1 << 20)}'\n)],
  "ml_literal_1mb" => [%(s = '''\n#{lines.call(1 << 20)}'''\n)],
  "ml_quotes" => [%(s = """\n#{%(ab"cd""ef gh) * 10_000}"""\n)],
  "ml_literal_quotes" => [%(s = '''\n#{"ab'cd''ef\\gh" * 10_000}'''\n)],
  "unsigned_ints" => [%(a = [#{Array.new(1000) { rng.rand(100_000) }.join(", ")}]\n)],
  "signed_ints" => [%(a = [#{Array.new(1000) { |i| (i.even? ? "-" : "+") + rng.rand(100_000).to_s }.join(", ")}]\n)],
  "signed_scalars" => [Array.new(1000) { |i| "k#{i} = -#{rng.rand(100_000)}\n" }.join],
  "floats" => [%(a = [#{Array.new(1000) { format("%.4f", rng.rand * 1000) }.join(", ")}]\n)],
  "inline_tables" => [Array.new(500) { |i| %(d#{i} = { version = "1.#{i}", optional = true, features = ["a", "b"] }\n) }.join],
  "datetimes" => [Array.new(500) { |i| "d#{i} = 1979-05-27T07:32:#{format("%02d", i % 60)}Z\n" }.join]
}.freeze

selected = ARGV.empty? ? WORKLOADS.keys : ARGV
unknown = selected - WORKLOADS.keys
abort("Unknown workloads: #{unknown.join(", ")} (known: #{WORKLOADS.keys.join(", ")})") unless unknown.empty?

fresh =
  if options[:unknown_coderange]
    # pack builds a String whose code range Ruby has not computed yet.
    ->(docs) { docs.map { |doc| [doc].pack("a*").force_encoding(Encoding::UTF_8) } }
  else
    ->(docs) { docs.map(&:dup) }
  end
now = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

if (child = options[:rss_child])
  inputs = fresh.call(WORKLOADS.fetch(child))
  GC.start
  File.write("/proc/self/clear_refs", "5") # resets VmHWM to the current RSS
  hwm = -> { File.read("/proc/self/status")[/^VmHWM:\s+(\d+)/, 1].to_i }
  before = hwm.call
  inputs.each(&parse)
  puts hwm.call - before
  exit
end

rss_supported = File.writable?("/proc/self/clear_refs")
ruby = [RbConfig.ruby, *(["--yjit"] if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?)]
child_args = ["--parser", options[:parser], "--lib", options[:lib], *("--unknown-coderange" if options[:unknown_coderange])]

puts RUBY_DESCRIPTION
puts "#{options[:parser]}#{" from #{options[:lib]}" if options[:parser] == "tomlrb"}" \
  "#{", unknown code range" if options[:unknown_coderange]}"
puts "workload          input KB     us/parse    allocs  peak RSS KB  digest"
selected.each do |name|
  docs = WORKLOADS.fetch(name)
  digest = Digest::SHA256.hexdigest(fresh.call(docs).map(&parse).inspect)[0, 12]

  inputs = fresh.call(docs)
  before = GC.stat(:total_allocated_objects)
  inputs.each(&parse)
  allocs = GC.stat(:total_allocated_objects) - before

  # Median of at least 5 timed parses spanning at least 0.5 s.
  samples = []
  deadline = now.call + 0.5
  until samples.size >= 5 && now.call > deadline
    inputs = fresh.call(docs)
    start = now.call
    inputs.each(&parse)
    samples << now.call - start
  end
  per_parse = samples.sort[samples.size / 2]

  rss = rss_supported ? IO.popen([*ruby, __FILE__, *child_args, "--rss-child", name], &:read).to_i : "-"
  puts format("%-16s %9.1f %12.1f %9d %12s  %s", name, docs.sum(&:bytesize) / 1024.0, per_parse * 1e6, allocs, rss, digest)
end
