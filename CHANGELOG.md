### Unreleased

Breaking changes (release as 3.0.0):

* Require Ruby 3.3 or later
* Read documents as TOML 1.1 by default. Every valid TOML 1.0 document parses unchanged; 1.1 additionally accepts `\e` and `\xHH` escapes, times without seconds, and inline tables that span lines, contain comments or end with a comma. `version: "1.0"` keeps rejecting those
* Fractional seconds are exact `Rational`s instead of `Float`s: `Time`, `LocalDateTime` and `LocalTime` values carry `56.123`, not `56.122999…`
* Remove `Tomlrb::Scanner`, `Tomlrb::Handler`, `Tomlrb::StringUtils`, `Tomlrb::GeneratedParser`, `Tomlrb::Keys` and `Tomlrb::Key`; `Tomlrb::Parser.new` now takes the document string. Key redefinitions raise `Tomlrb::ParseError` as before
* `require "tomlrb"` no longer loads `time` and `stringio`

Features:

* TOML 1.1 support, selected with `version: "1.1"` (default) or `"1.0"`

Security:

* Nesting depth of arrays and inline tables is limited only by memory: they are parsed with an explicit stack

Performance:

* Replace the Racc grammar with a hand-written single-pass parser; Racc is no longer used. Parsing executes 2.0-2.6x fewer instructions than perfect_toml 0.9.1 and 10-14x fewer than 2.0.4 (2.4-2.7x and 12-15x with YJIT)
* Multi-line strings are scanned by searching for the closing quotes, a backslash or a control character: a 1 MB `"""` or `'''` string parses 25x faster, peak memory no longer grows by about 48 MB per MB of string, and quote-dense content (`ab"cd""ef`) no longer costs a step per quote

Conformance (every TOML 1.0 and 1.1 case of toml-test 2.2.0 passes):

* An escaped backslash right before a closing `"""` (`"""x\\"""`) ends the string
* Reject a carriage return not followed by a line feed in multi-line strings, and trim a CRLF (not just LF) right after an opening `"""` or `'''`
* Parse bare keys that start with `true`, `false`, `inf` or `nan` (`trueval`, `inf-x`) or look like dates and numbers (`1979-05-27a`, `0x1f`, `[[1e5]]`), and reject keys containing `:`
* Reject empty values in inline tables (`{a = }`), inline tables that are not assigned to a key, and dotted keys that extend an inline table
* Reject spaced array-of-tables brackets (`[ [a]]`, `[[a] ]`) on indented and CRLF lines too, and stop rejecting multi-line arrays whose line starts with `[ [`
* Separate date and time only with `T`, `t` or a space, accept an offset only after a time, and reject negative years and days that do not exist (`1979-06-31T00:00:00-00:00`)
* Reject floats with leading zeros (`01e5`) and accept underscores in exponents (`1e1_0`)

Other:

* Parse errors report the line and column (in characters)
* `benchmarks/matrix.rb` measures time, allocations and peak memory over a set of generated workloads; `benchmarks/bench.rb` accepts several files
* `LocalDate`, `LocalDateTime` and `LocalTime` validate their fields arithmetically and build their `Time` on first use
* Ship RBS type signatures in `sig/`

### 2.0.5 - 2026-10-15

* Fix exponential backtracking (ReDoS) when scanning unterminated basic and literal strings ([GHSA-gq8g-3x53-v8fh](https://github.com/fbernier/tomlrb/security/advisories/GHSA-gq8g-3x53-v8fh))
* Fix `SystemStackError` and quadratic scan time on long runs of spaces/tabs ([GHSA-mc56-vpwf-3m26](https://github.com/fbernier/tomlrb/security/advisories/GHSA-mc56-vpwf-3m26))
* Literal strings no longer treat `\'` as an escaped quote, per the TOML spec
* Add SECURITY.md: report vulnerabilities through GitHub private vulnerability reporting
* Declare racc as a runtime dependency: Ruby 3.3 made it a bundled gem, so under Bundler `require "tomlrb"` failed unless the app's Gemfile pulled racc in
* Stop shipping the unused `parser.y` grammar source in the gem

Both vulnerabilities were reported by [@tsigouris007](https://github.com/tsigouris007), advised by [@kpatsakis](https://github.com/kpatsakis).

### 2.0.4 - 2025-12-18

* Update Racc to v1.8.1
* Code cleanup
* Fix conformance to TOML v1.0.0

### 2.0.3 - 2022-05-28

* Enable symbolize_keys: true for inline tables

### 2.0.2 - 2022-05-25

* Conform to TOML v1.0.0

### 2.0.1 - 2020-12-20

* Fix error with table nested under array-of-tables
* Some performance improvements

### 2.0.0 - 2020-11-26

* Conform to TOML v1.0.0-rc3

#### Breanking Changes ####

TOML v0.5.0 introduced new value types: Local Date-Time, Local Date and Local Time which represent time without time zone information. Tomlrb also introduced corresponding classes starting from v2.0.0. By this change, some table values such as `2020-11-24T20:32:18`, `2020-11-24` or `20:32:18` are not treated as strings but as new the classes `Tomlrb::LocalDateTime`, `Tomlrb::LocalDate` and `Tomlrb::LocalTime` respectively. You can get the string values by calling `#to_s` method on any of those classes. Additionally, You can also get `Time` objects with the `#to_time` method. See [API documentation](https://www.rubydoc.info/gems/tomlrb) for the methods' details.

### 1.3.0 - 2020-03-19

* Fix error with falsy table values

### 1.2.9 - 2019-11-22

* Fixes and cleanups for ruby 2.7

### 1.2.8 - 2018-12-18

* Reduce gem size by excluding tests (tas50)
* Make integer and float parsing closer to the spec (sgarciac)

### 1.2.7 - 2018-07-12

* Datetime should be UTC when no offset or timezone are specified

### 1.2.6 - 2017-10-23

* Fix issue where an unclosed table could make the parsing loop infinitely.
* Proper string escaping

### 1.1.3 - 2015-11-24

* Bare integers can be used as keys as per the spec
