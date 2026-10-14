# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/toml_test_json"

# The TOML 1.0 cases of toml-test (https://github.com/toml-lang/toml-test), compared
# the way its official runner does. CI also runs that runner itself against
# bin/toml-test-decoder.
describe "toml-test" do
  root = File.expand_path("../toml-test/tests", __dir__)
  File.readlines(File.join(root, "files-toml-1.0.0"), chomp: true).grep(/\.toml\z/).each do |file|
    path = File.join(root, file)

    if file.start_with?("valid/")
      it "parses #{file}" do
        expected = JSON.parse(File.read(path.sub(/\.toml\z/, ".json")))
        actual = TomlTestJSON.describe(Tomlrb.load_file(path))
        _(TomlTestJSON.normalize(actual)).must_equal TomlTestJSON.normalize(expected)
      end
    else
      it "rejects #{file}" do
        _ { Tomlrb.load_file(path) }.must_raise Tomlrb::ParseError, ArgumentError, RangeError
      end
    end
  end
end
