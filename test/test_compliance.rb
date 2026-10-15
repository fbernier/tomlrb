# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/toml_test_json"

# The toml-test cases (https://github.com/toml-lang/toml-test) for each TOML version,
# compared the way its official runner does. CI also runs that runner itself
# against bin/toml-test-decoder.
{"1.0" => "files-toml-1.0.0", "1.1" => "files-toml-1.1.0"}.each do |version, list|
  describe "toml-test #{version}" do
    root = File.expand_path("../toml-test/tests", __dir__)
    File.readlines(File.join(root, list), chomp: true).grep(/\.toml\z/).each do |file|
      path = File.join(root, file)

      if file.start_with?("valid/")
        it "parses #{file}" do
          expected = JSON.parse(File.read(path.sub(/\.toml\z/, ".json")))
          actual = TomlTestJSON.describe(Tomlrb.load_file(path, version: version))
          _(TomlTestJSON.normalize(actual)).must_equal TomlTestJSON.normalize(expected)
        end
      else
        it "rejects #{file}" do
          _ { Tomlrb.load_file(path, version: version) }.must_raise Tomlrb::ParseError, ArgumentError, RangeError
        end
      end
    end
  end
end
