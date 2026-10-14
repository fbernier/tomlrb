# Tomlrb

[![Code Climate](https://codeclimate.com/github/fbernier/tomlrb/badges/gpa.svg)](https://codeclimate.com/github/fbernier/tomlrb)
[![Gem Version](https://badge.fury.io/rb/tomlrb.svg)](http://badge.fury.io/rb/tomlrb)
[![Build status](https://github.com/fbernier/tomlrb/workflows/ci/badge.svg)](https://github.com/fbernier/tomlrb/actions)

A fast, pure-Ruby [TOML](https://github.com/toml-lang/toml) parser supporting the 1.0.0 version of the spec. Requires Ruby 3.0 or later.

## TODO

* Dumper

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tomlrb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tomlrb

## Usage

```ruby
Tomlrb.parse("[toml]\na = [\"array\", 123]")
```

or

```ruby
Tomlrb.load_file('my_file', symbolize_keys: true)
```

## Benchmark

`ruby benchmarks/bench.rb [file]` compares against [toml-rb](https://github.com/emancu/toml-rb) and [perfect_toml](https://github.com/mame/perfect_toml) when they are installed. It parses `test/example-v0.4.0.toml` unless given a file.

CPU instructions per parse (fewer is better), measured with `perf stat` on CRuby 3.3 without YJIT. YJIT shows the same ratios.

| Input | tomlrb | perfect_toml 0.9.1 | tomlrb 2.0.4 |
|---|---|---|---|
| `test/example-v0.4.0.toml` (5 KB) | 1.9 M | 3.4 M | 17.7 M |
| 300 crates.io `Cargo.toml` files (620 KB) | 260 M | 578 M | 3,180 M |
| rust-lang/rust `Cargo.lock` (158 KB) | 50 M | 123 M | 677 M |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

Do not forget to regenerate the parser when you modify rules in the `parser.y` file using `rake compile`.

Run the tests using `rake test`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/tomlrb/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Thanks

Thanks to [@jpbougie](https://github.com/jpbougie) for the crash course on  the Chomsky hierarchy and general tips.
