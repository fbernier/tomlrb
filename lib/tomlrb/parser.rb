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
end
