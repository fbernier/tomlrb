# frozen_string_literal: true

require_relative "tomlrb/version"
require_relative "tomlrb/local_date"
require_relative "tomlrb/local_date_time"
require_relative "tomlrb/local_time"
require_relative "tomlrb/parser"

module Tomlrb
  class ParseError < StandardError; end

  # Parses a TOML document into a Hash.
  #
  # @param string_or_io [String, #read] the document
  # @param options [Hash] the options hash
  # @option options [Boolean] :symbolize_keys (false) whether to return the keys as symbols or strings
  # @option options ["1.1", "1.0"] :version ("1.1") the TOML spec to follow. A valid 1.0 document parses the
  #   same under 1.1; "1.0" also rejects what 1.1 added (`\e`, `\xHH`, times without seconds, multi-line
  #   inline tables), for when another consumer of the file only reads 1.0
  # @return [Hash] the Ruby data structure represented by the input
  # @raise [ParseError] on invalid TOML
  def self.parse(string_or_io, **options)
    src = string_or_io.is_a?(String) ? string_or_io : string_or_io.read
    Parser.new(src, **options).parse
  end

  # Reads a UTF-8 file and parses it; see {.parse} for the options.
  #
  # @param path [String, Pathname] the path to the file
  # @return [Hash] the Ruby data structure represented by the input
  def self.load_file(path, **options)
    # Read as UTF-8 whatever the default external encoding (locale, -E) is.
    parse(File.read(path, encoding: "utf-8"), **options)
  end
end
