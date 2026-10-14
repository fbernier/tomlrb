# Tomlrb

[![CI](https://github.com/fbernier/tomlrb/actions/workflows/ci.yml/badge.svg)](https://github.com/fbernier/tomlrb/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/tomlrb)](https://rubygems.org/gems/tomlrb)

A fast, pure-Ruby [TOML](https://toml.io) parser with no runtime dependencies, for [TOML 1.1](https://toml.io/en/v1.1.0) and [1.0](https://toml.io/en/v1.0.0). It passes every case of the official [toml-test](https://github.com/toml-lang/toml-test) suite for both versions.

Requires Ruby 3.3 or later. Runs on CRuby (with or without YJIT), JRuby and TruffleRuby.

## Installation

```sh
bundle add tomlrb
```

## Usage

```ruby
require "tomlrb"

Tomlrb.parse(%(title = "TOML"\n[owner]\nname = "Tom"))
# => {"title" => "TOML", "owner" => {"name" => "Tom"}}

Tomlrb.load_file("config.toml", symbolize_keys: true)
# => {title: "TOML", owner: {name: "Tom"}}
```

`Tomlrb.parse` also accepts an IO. Invalid documents raise `Tomlrb::ParseError` with the line and column; impossible dates and times raise `ArgumentError`.

Documents are read as TOML 1.1, which accepts every valid TOML 1.0 document unchanged. Pass `version: "1.0"` to also reject what 1.1 added (`\e` and `\xHH` escapes, times without seconds, inline tables spanning lines or ending with a comma), for example when a file must stay readable by a 1.0-only parser:

```ruby
Tomlrb.parse("t = 07:32")                 # => {"t" => #<Tomlrb::LocalTime: 07:32:00>}
Tomlrb.parse("t = 07:32", version: "1.0") # raises Tomlrb::ParseError
```

TOML values map to Ruby as follows:

| TOML | Ruby |
|---|---|
| string | `String` |
| integer | `Integer` |
| float | `Float` (`inf`, `nan` included) |
| boolean | `true`, `false` |
| offset date-time | `Time` |
| local date-time | `Tomlrb::LocalDateTime` |
| local date | `Tomlrb::LocalDate` |
| local time | `Tomlrb::LocalTime` |
| array | `Array` |
| table, inline table | `Hash` |

Fractional seconds are exact (`Rational`), and the local types convert with `#to_time`.

Type signatures for the public API are in [`sig/`](sig/tomlrb.rbs).

## Benchmark

`ruby benchmarks/bench.rb [file...]` compares against [toml-rb](https://github.com/emancu/toml-rb) and [perfect_toml](https://github.com/mame/perfect_toml) when they are installed. Each iteration parses every given file (`test/example-v0.4.0.toml` by default).

`ruby [--yjit] benchmarks/matrix.rb` runs one parser over generated workloads, one per input shape (plain, escaped and 1 MB strings, plain and quote-dense multi-line strings, signed and unsigned numbers, floats, inline tables, date-times, many small documents), and reports time, Ruby allocations, peak RSS growth and a digest of the results per workload. `--lib DIR` loads tomlrb from another checkout, so equal digests show that two versions parse alike; `--parser perfect_toml` measures perfect_toml instead. Inputs keep the known encoding code range a string from `File.read` has; `--unknown-coderange` also times the UTF-8 validation of a string whose code range Ruby has not computed.

CPU instructions per parse (fewer is better), measured with `perf stat` on CRuby 3.3 without YJIT. With YJIT tomlrb's lead grows: 2.4-2.7x fewer instructions than perfect_toml and 12-15x fewer than 2.0.4. The crates.io corpus is the first 300 `Cargo.toml` files of a local Cargo registry (`~/.cargo/registry/src/*/*/Cargo.toml`, sorted by path) that all three parsers accept.

| Input | tomlrb | perfect_toml 0.9.1 | tomlrb 2.0.4 |
|---|---|---|---|
| `test/example-v0.4.0.toml` (5 KB) | 1.7 M | 3.4 M | 17.7 M |
| 300 crates.io `Cargo.toml` files (623 KB) | 244 M | 562 M | 3,117 M |
| rust-lang/rust `Cargo.lock` (158 KB) | 48 M | 122 M | 686 M |

`ruby benchmarks/profile.rb [file]` records a [Vernier](https://github.com/jhawthorn/vernier) profile.

## Development

```sh
bin/setup            # fetch the toml-test submodule and install gems
bundle exec rake     # tests, Standard (lint), RBS validation
bundle exec rake toml_test   # the official toml-test runner (needs Go)
bin/console          # IRB with tomlrb loaded
```

Releases are published from GitHub Actions with [trusted publishing](https://guides.rubygems.org/trusted-publishing/): bump `lib/tomlrb/version.rb`, add the CHANGELOG entry, then run the `release` workflow.

## Thanks

Thanks to [@jpbougie](https://github.com/jpbougie) for the crash course on the Chomsky hierarchy and general tips.
