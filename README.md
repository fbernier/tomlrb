# Tomlrb

[![Code Climate](https://codeclimate.com/github/fbernier/tomlrb/badges/gpa.svg)](https://codeclimate.com/github/fbernier/tomlrb) [![Build Status](https://travis-ci.org/fbernier/tomlrb.svg)](https://travis-ci.org/fbernier/tomlrb) [![Gem Version](https://badge.fury.io/rb/tomlrb.svg)](http://badge.fury.io/rb/tomlrb)

A Racc based [TOML](https://github.com/toml-lang/toml) Ruby parser supporting the 0.4.0 version of the spec.


## TODO

* Better tests
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

You can run the benchmark against the only other v0.4.0 compliant parser to my knowledge with `ruby benchmarks/bench.rb`.

Here are the results on my machine:

```
Warming up --------------------------------------
      emancu/toml-rb     1.000  i/100ms
     fbernier/tomlrb    47.000  i/100ms
Calculating -------------------------------------
      emancu/toml-rb     13.501  (± 7.4%) i/s -     68.000  in   5.050832s
     fbernier/tomlrb    502.861  (± 3.6%) i/s -      2.538k in   5.053877s
Comparison:
     fbernier/tomlrb:      502.9 i/s
      emancu/toml-rb:       13.5 i/s - 37.25x  slower

# MEMORY
Calculating -------------------------------------
      emancu/toml-rb     2.733M memsize (    40.000  retained)
                        35.718k objects (     1.000  retained)
                        50.000  strings (     1.000  retained)
     fbernier/tomlrb   115.778k memsize (    80.000  retained)
                         2.422k objects (     2.000  retained)
                        50.000  strings (     2.000  retained)

Comparison:
     fbernier/tomlrb:     115778 allocated
      emancu/toml-rb:    2732978 allocated - 23.61x more
```

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
