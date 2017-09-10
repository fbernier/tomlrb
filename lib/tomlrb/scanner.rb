require 'strscan'

module Tomlrb
  class Scanner
    COMMENT = /#.*/
    IDENTIFIER = /[A-Za-z0-9_-]+/
    SPACE = /[ \t\r\n]/
    STRING_BASIC = /(["])(?:\\?.)*?\1/
    STRING_MULTI = /"{3}([\s\S]*?"{3,4})/m
    STRING_LITERAL = /(['])(?:\\?.)*?\1/
    STRING_LITERAL_MULTI = /'{3}([\s\S]*?'{3})/m
    DATETIME = /(-?\d{4})-(\d{2})-(\d{2})(?:(?:t|\s)(\d{2}):(\d{2}):(\d{2}(?:\.\d+)?))?(z|[-+]\d{2}:\d{2})?/i
    FLOAT = /[+-]?(?:[0-9_]+\.[0-9_]*|\.[0-9_]+|\d+(?=[eE]))(?:[eE][+-]?[0-9_]+)?/
    INTEGER = /[+-]?\d(_?\d)*(?![A-Za-z0-9_-]+)/
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
      when @ss.scan(DATETIME) then process_datetime
      when text = @ss.scan(STRING_MULTI) then [:STRING_MULTI, text[3..-4]]
      when text = @ss.scan(STRING_BASIC) then [:STRING_BASIC, text[1..-2]]
      when text = @ss.scan(STRING_LITERAL_MULTI) then [:STRING_LITERAL_MULTI, text[3..-4]]
      when text = @ss.scan(STRING_LITERAL) then [:STRING_LITERAL, text[1..-2]]
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

    def process_datetime
      if @ss[7].nil?
        offset = Time.now.utc_offset
      else
        offset = @ss[7].gsub('Z', '+00:00')
      end
      args = [ @ss[1], @ss[2], @ss[3], @ss[4] || 0, @ss[5] || 0, @ss[6].to_f, offset ]
      [:DATETIME, args]
    end
  end
end
