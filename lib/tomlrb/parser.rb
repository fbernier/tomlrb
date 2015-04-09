class Tomlrb::Parser < Tomlrb::GeneratedParser
  attr_reader :handler

  def initialize(tokenizer, handler = Tomlrb::Handler.new)
    @tokenizer = tokenizer
    @handler   = handler
    @yydebug = true
    super()
  end

  def next_token
    @tokenizer.next_token
  end

  def parse
    do_parse
    handler
  end
end
