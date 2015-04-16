require 'strscan'

module Tomlrb
  class Scanner
    COMMENT = /#.+/
    IDENTIFIER = /[A-Za-z0-9_-]+/
    SPACE = /\A\s+/
    STRING_SINGLE = /"[^"]*"/
    STRING_MULTI = /"[^"]*"/
    DATETIME = /(-?\d{4})-(\d{2})-(\d{2})(?:t|\s)(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(z|[-+]\d{2}:\d{2})/i
    FLOAT = /[+-]?(?:[0-9_]+\.[0-9_]*|\.[0-9_]+|\d+(?=[eE]))(?:[eE][+-]?[0-9_]+)?/
    INTEGER = /[+-]?\d(_?\d)*/
    TRUE   = /true/
    FALSE  = /false/

    def initialize(io)
      @ss = StringScanner.new(io.read)
    end

    def next_token
      return if @ss.eos?

      case
      when @ss.scan(SPACE) then next_token
      when @ss.scan(COMMENT) then next_token
      when text = @ss.scan(DATETIME) then [:DATETIME, text]
      when text = @ss.scan(STRING_SINGLE) then [:STRING, text[1..-2]]
      when text = @ss.scan(FLOAT) then [:FLOAT, text]
      when text = @ss.scan(INTEGER) then [:INTEGER, text]
      when text = @ss.scan(TRUE)   then [:TRUE, text]
      when text = @ss.scan(FALSE)  then [:FALSE, text]
      when text = @ss.scan(IDENTIFIER) then [:IDENTIFIER, text]
      else
        x = @ss.getch
        [x, x]
      end
    end
  end
end
