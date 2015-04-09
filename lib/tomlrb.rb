require "tomlrb/version"
require "tomlrb/generated_parser"
require "tomlrb/scanner"
require "tomlrb/parser"
require "tomlrb/handler"

module Tomlrb
  def self.parse(string_or_io)
    io = string_or_io.is_a?(String) ? StringIO.new(string_or_io) : string_or_io
    scanner = Scanner.new(io)
    parser = Parser.new(scanner)
    handler = parser.parse
    handler.result
  end
end
