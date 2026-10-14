# frozen_string_literal: true

require_relative "lib/tomlrb/version"

Gem::Specification.new do |spec|
  spec.name = "tomlrb"
  spec.version = Tomlrb::VERSION
  spec.authors = ["Francois Bernier"]
  spec.email = ["frankbernier@gmail.com"]

  spec.summary = "A fast, pure-Ruby TOML 1.0 parser"
  spec.description = "Parses TOML 1.0 documents into Ruby Hashes. Pure Ruby, no runtime dependencies, " \
                     "checked against the official toml-test suite."
  spec.homepage = "https://github.com/fbernier/tomlrb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "documentation_uri" => "https://rubydoc.info/gems/tomlrb",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
end
