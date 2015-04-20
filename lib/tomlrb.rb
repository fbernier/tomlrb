require 'time'
require 'stringio'
require "tomlrb/version"
require 'tomlrb/string_utils'
require "tomlrb/scanner"
require "tomlrb/parser"
require "tomlrb/handler"

module Tomlrb

  def self.parse(string_or_io, **options)
    io = string_or_io.is_a?(String) ? StringIO.new(string_or_io) : string_or_io
    scanner = Scanner.new(io)
    parser = Parser.new(scanner, options)
    handler = parser.parse
    handler.output
  end

  def self.load_file(path, **options)
    Tomlrb.parse(File.read(path), options)
  end
end
