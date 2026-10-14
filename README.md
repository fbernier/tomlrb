# Tomlrb

[![CI](https://github.com/fbernier/tomlrb/actions/workflows/ci.yml/badge.svg)](https://github.com/fbernier/tomlrb/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/tomlrb)](https://rubygems.org/gems/tomlrb)

A fast, pure-Ruby [TOML 1.0](https://toml.io/en/v1.0.0) parser with no runtime dependencies. It passes every TOML 1.0 case of the official [toml-test](https://github.com/toml-lang/toml-test) suite.

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

`ruby benchmarks/bench.rb [file]` compares against [toml-rb](https://github.com/emancu/toml-rb) and [perfect_toml](https://github.com/mame/perfect_toml) when they are installed. It parses `test/example-v0.4.0.toml` unless given a file.

CPU instructions per parse (fewer is better), measured with `perf stat` on CRuby 3.3 without YJIT. YJIT shows the same ratios.

| Input | tomlrb | perfect_toml 0.9.1 | tomlrb 2.0.4 |
|---|---|---|---|
| `test/example-v0.4.0.toml` (5 KB) | 1.9 M | 3.4 M | 17.7 M |
| 300 crates.io `Cargo.toml` files (620 KB) | 260 M | 578 M | 3,180 M |
| rust-lang/rust `Cargo.lock` (158 KB) | 50 M | 123 M | 677 M |

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
