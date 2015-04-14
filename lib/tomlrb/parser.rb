require "tomlrb/generated_parser"

class Tomlrb::Parser < Tomlrb::GeneratedParser

  def initialize(tokenizer, handler = Tomlrb::Handler.new)
    @tokenizer = tokenizer
    @handler   = handler
    super()
  end

  def next_token
    @tokenizer.next_token
  end

  def parse
    do_parse
    @handler
  end

  def self.unescape_chars(str)
    str
      .gsub(/\\0/, "\0")
      .gsub(/\\t/, "\t")
      .gsub(/\\n/, "\n")
      .gsub(/\\\"/, '"')
      .gsub(/\\r/, "\r")
      .gsub(/\\\\/, '\\')
  end

  def self.strip_spaces(str)
    str.gsub(/\\\r?\n[\n\t\r ]*/, '')
  end
end
