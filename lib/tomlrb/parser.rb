# frozen_string_literal: true

require "strscan"

module Tomlrb
  # Single-pass TOML 1.0 parser over a StringScanner.
  #
  # Costs that shape the code (CRuby 3.3, instructions): a regex call has about
  # 1000 fixed overhead, an anchored `[class]*` loop then costs ~80 per byte while
  # an unanchored search for a character class costs ~11 per byte, a capture
  # 600-800, a `getbyte` ~190 (~40 under YJIT). So the parser dispatches on bytes
  # through lookup tables, fuses the commonest shapes into one regex (`key =`,
  # a plain string or integer plus the rest of its line, an array string element
  # plus its comma), and skips comments by searching for the character that ends
  # them. Arrays and inline tables use an explicit stack, so nesting depth is
  # bounded by memory rather than the VM stack. Every regex is linear-time:
  # alternatives start with disjoint characters and repeated groups are atomic or
  # cannot overlap.
  class Parser
    # Kinds of the tables the document creates, tracked by identity in @kinds.
    # Hashes and Arrays missing from @kinds (inline tables, array values) are final.
    IMPLICIT = 1        # created as a header prefix (`a` in `[a.b]`); its own header may still define it
    HEADER = 2          # defined by `[header]`, or an element of an array of tables
    DOTTED = 3          # defined by a dotted key (`a` in `a.b = 1`); only dotted keys may extend it
    ARRAY_OF_TABLES = 4

    UTF_8 = Encoding::UTF_8

    CTRL = '\x00-\x08\x0a-\x1f\x7f' # control characters, tab excluded
    ML_CTRL = '\x00-\x08\x0b-\x1f\x7f' # same, also allowing LF; CR only as part of CRLF
    EOL_SRC = "[ \\t]*(?:#[^#{CTRL}]*)?(?:\\r?\\n|\\z)"

    EOL = /#{EOL_SRC}/
    WHITESPACE = /(?:[ \t\n]|\r\n)+/
    SPACES = /[ \t]+/
    EQUALS = /[ \t]*=[ \t]*/
    # Searched for, not matched: where a block of comment lines ends. It stops at a
    # line break not followed by another comment line, or at a character no comment
    # may contain, so consecutive comment lines cost one call.
    COMMENT_BLOCK_END = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]|\r(?!\n)|\r?\n(?![ \t]*#)/

    BARE_KEY = /[A-Za-z0-9_-]+/
    KEY_EQUALS = /([A-Za-z0-9_-]+)[ \t]*=[ \t]*/
    INLINE_KEY_EQUALS = /[ \t]*([A-Za-z0-9_-]+)[ \t]*=[ \t]*/
    TABLE_HEADER = /\[[ \t]*([A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*)[ \t]*\]#{EOL_SRC}/
    ARRAY_TABLE_HEADER = /\[\[[ \t]*([A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*)[ \t]*\]\]#{EOL_SRC}/
    TABLE_CLOSE = /\]#{EOL_SRC}/
    ARRAY_TABLE_CLOSE = /\]\]#{EOL_SRC}/

    SIMPLE_BASIC_STRING_EOL = /"([^"\\#{CTRL}]*)"#{EOL_SRC}/
    # A plain string array element with its comma and the whitespace after it, or
    # the last element before `]` (closing after a value or after a trailing comma
    # is the same thing, so the loop needs no record of which it was). The leading
    # whitespace is atomic: giving it back a character at a time would rerun the
    # lookahead over the rest of it, quadratic in the run's length.
    ELEMENT_END = '(?>[ \t]*)(?:,[ \t]*(?:\r?\n[ \t]*)?|(?=[ \t\r\n]*\]))'
    STRING_ELEMENT = /"([^"\\#{CTRL}]*)"#{ELEMENT_END}/
    # The same for an integer; the separator rules out a float or date continuing it.
    INTEGER_ELEMENT = /([+-]?(?:0|[1-9](?:_?[0-9])*))#{ELEMENT_END}/
    STRING_SEGMENT = /[^"\\#{CTRL}]*/
    MULTILINE_STRING_SEGMENT = /(?>[^"\\#{ML_CTRL}]+|\r\n)*/
    UNICODE_ESCAPE = /\\(?:u([0-9A-Fa-f]{4})|U([0-9A-Fa-f]{8}))/
    # A backslash ending a line drops the line break and all whitespace after it.
    LINE_ENDING_BACKSLASH = /\\[ \t]*\r?\n(?:[ \t\n]|\r\n)*/
    LITERAL_STRING = /'([^'#{CTRL}]*)'/
    LITERAL_STRING_EOL = /'([^'#{CTRL}]*)'#{EOL_SRC}/
    # Up to two quotes may end the content: `'''a'''''` is `a''`.
    MULTILINE_LITERAL_STRING = /'''((?>[^'#{ML_CTRL}]+|\r\n|'(?!''))*)('{0,2})'''/

    INTEGER_SRC = "[+-]?(?:0|[1-9](?:_?[0-9])*)"
    FLOAT_SRC = "#{INTEGER_SRC}(?:\\.[0-9](?:_?[0-9])*(?:[eE][+-]?[0-9](?:_?[0-9])*)?|[eE][+-]?[0-9](?:_?[0-9])*)"
    INTEGER = /#{INTEGER_SRC}/
    INTEGER_EOL = /(#{INTEGER_SRC})#{EOL_SRC}/
    FLOAT = /#{FLOAT_SRC}/
    FLOAT_EOL = /(#{FLOAT_SRC})#{EOL_SRC}/
    NON_DECIMAL_INTEGER = /0(?:x[0-9A-Fa-f](?:_?[0-9A-Fa-f])*|o[0-7](?:_?[0-7])*|b[01](?:_?[01])*)/
    FLOAT_KEYWORD = /[+-]?(?:inf|nan)/
    TRUE_KEYWORD = /true/
    FALSE_KEYWORD = /false/
    TRUE_EOL = /true#{EOL_SRC}/
    FALSE_EOL = /false#{EOL_SRC}/
    TIME_SRC_V1_0 = '(\d{2}):(\d{2}):(\d{2}(?:\.\d+)?)'
    TIME_SRC_V1_1 = '(\d{2}):(\d{2})(?::(\d{2}(?:\.\d+)?))?' # seconds optional
    LOCAL_TIME_V1_0 = /#{TIME_SRC_V1_0}/
    LOCAL_TIME_V1_1 = /#{TIME_SRC_V1_1}/
    DATETIME_V1_0 = /(\d{4})-(\d{2})-(\d{2})(?:[Tt ]#{TIME_SRC_V1_0}([Zz]|[-+]\d{2}:\d{2})?)?/
    DATETIME_V1_1 = /(\d{4})-(\d{2})-(\d{2})(?:[Tt ]#{TIME_SRC_V1_1}([Zz]|[-+]\d{2}:\d{2})?)?/

    ESCAPE_CHARS_V1_0 = {"b" => "\b", "t" => "\t", "n" => "\n", "f" => "\f", "r" => "\r", '"' => '"', "\\" => "\\"}.freeze
    ESCAPE_CHARS_V1_1 = ESCAPE_CHARS_V1_0.merge("e" => "\e").freeze
    # Escape character byte -> its value.
    ESCAPES_V1_0, ESCAPES_V1_1 = [ESCAPE_CHARS_V1_0, ESCAPE_CHARS_V1_1].map do |chars|
      Array.new(256).tap { |table| chars.each { |char, value| table[char.ord] = value } }.freeze
    end
    HEX_ESCAPE = /\\x([0-9A-Fa-f]{2})/
    # Content for the 0-2 quotes allowed right before a closing `"""`.
    TRAILING_QUOTES = ["", '"', '""'].freeze

    # What differs between the TOML versions read. 1.1 only relaxes 1.0: a valid
    # 1.0 document means the same under either, 1.0 just rejects more.
    Spec = Data.define(
      :local_time,     # seconds required in 1.0, optional in 1.1
      :datetime,       # likewise
      :escapes,        # escape character byte -> its value (1.1 adds \e)
      :hex_escapes,    # \xHH (1.1)
      :inline_newlines # newlines, comments and a trailing comma in inline tables (1.1)
    )
    SPECS = {
      "1.0" => Spec.new(local_time: LOCAL_TIME_V1_0, datetime: DATETIME_V1_0, escapes: ESCAPES_V1_0,
        hex_escapes: false, inline_newlines: false),
      "1.1" => Spec.new(local_time: LOCAL_TIME_V1_1, datetime: DATETIME_V1_1, escapes: ESCAPES_V1_1,
        hex_escapes: true, inline_newlines: true)
    }.freeze

    LBRACKET = "[".ord
    RBRACKET = "]".ord
    LBRACE = "{".ord
    RBRACE = "}".ord
    COMMA = ",".ord
    DOT = ".".ord
    COLON = ":".ord
    DASH = "-".ord
    ZERO = "0".ord
    HASH = "#".ord
    BACKSLASH = "\\".ord
    NEWLINE = "\n".ord
    CR = "\r".ord
    SPACE = " ".ord
    TAB = "\t".ord
    DQUOTE = '"'.ord
    SQUOTE = "'".ord
    LOWER_E = "e".ord
    UPPER_E = "E".ord
    LOWER_I = "i".ord
    LOWER_N = "n".ord
    NON_DECIMAL_BASES = {"x".ord => 16, "o".ord => 8, "b".ord => 2}.freeze

    def self.byte_table(classes)
      table = Array.new(256)
      classes.each { |chars, klass| chars.each_byte { |b| table[b] = klass } }
      table.freeze
    end

    # What a statement starting with this byte is; anything else is a key.
    STATEMENT_START = byte_table(" \t\n\r#" => :gap, "[" => :header)
    GAP_START = byte_table(" \t\n\r#" => true)
    LINE_BREAK_OR_COMMENT = byte_table("\n\r#" => true)
    VALUE_START = byte_table(
      '"' => :basic_string, "'" => :literal_string, "0123456789" => :digit, "+-" => :sign,
      "t" => :true_keyword, "f" => :false_keyword, "in" => :inf_or_nan, "[" => :array, "{" => :inline_table
    )

    # @param version ["1.1", "1.0"] the TOML spec to follow; "1.0" also rejects what 1.1 added
    def initialize(src, version: "1.1", symbolize_keys: false, **)
      spec = SPECS.fetch(version) do
        raise ArgumentError, "Unsupported TOML version #{version.inspect} (supported: #{SPECS.keys.join(", ")})"
      end
      if src.encoding != UTF_8
        src = (src.encoding == Encoding::BINARY) ? src.dup.force_encoding(UTF_8) : src.encode(UTF_8)
      end
      raise ParseError, "Invalid UTF-8 in document" unless src.valid_encoding?

      @src = src
      @ss = StringScanner.new(src)
      @symbolize_keys = symbolize_keys ? true : false
      @local_time = spec.local_time
      @datetime = spec.datetime
      @escapes = spec.escapes
      @hex_escapes = spec.hex_escapes
      @inline_newlines = spec.inline_newlines
      @root = {}
      @current = @root
      @kinds = {}.compare_by_identity
    end

    def parse
      ss = @ss
      src = @src
      while (byte = src.getbyte(ss.pos))
        case STATEMENT_START[byte]
        when :gap then skip_gap
        when :header then header
        else key_value
        end
      end
      @root
    end

    private

    # Statements

    # Keys are frozen before insertion: Hash#[]= would otherwise intern each
    # unfrozen String key through the fstring table, hashing it twice.
    def key_value
      ss = @ss
      if ss.skip(KEY_EQUALS)
        key = ss[1]
        key = @symbolize_keys ? key.to_sym : key.freeze
        value = line_value
        table = @current
        conflict([key]) if table.key?(key)
        table[key] = value
      else
        keys = key_path
        error("Expected '=' after key") unless ss.skip(EQUALS)
        define(@current, keys, line_value)
      end
    end

    # A value that must be followed by the end of its line; the common scalars
    # are matched together with that line end in one regex.
    def line_value
      ss = @ss
      byte = @src.getbyte(ss.pos)
      case VALUE_START[byte || 0]
      when :basic_string
        return ss[1] if ss.skip(SIMPLE_BASIC_STRING_EOL)
      when :literal_string
        return ss[1] if ss.skip(LITERAL_STRING_EOL)
      when :digit
        unless date_or_time_ahead?
          return ss[1].to_i if ss.skip(INTEGER_EOL)
          return ss[1].to_f if ss.skip(FLOAT_EOL)
        end
      when :true_keyword
        return true if ss.skip(TRUE_EOL)
      when :false_keyword
        return false if ss.skip(FALSE_EOL)
      when :array, :inline_table
        value = container(byte)
        error("Expected end of line after value") unless ss.skip(EOL)
        return value
      end
      value = scalar(byte)
      error("Expected end of line after value") unless ss.skip(EOL)
      value
    end

    def header
      ss = @ss
      array = @src.getbyte(ss.pos + 1) == LBRACKET
      if ss.skip(array ? ARRAY_TABLE_HEADER : TABLE_HEADER)
        # Frozen only where a table is created: most header keys just look up an existing one.
        keys = ss[1].split(".")
        keys.map!(&:to_sym) if @symbolize_keys
      else
        ss.pos += array ? 2 : 1
        skip_spaces
        keys = key_path
        error(array ? "Expected ']]' after array of tables name" : "Expected ']' after table name") unless
          ss.skip(array ? ARRAY_TABLE_CLOSE : TABLE_CLOSE)
      end
      array ? open_array_of_tables(keys) : open_table(keys)
    end

    def key_path
      ss = @ss
      src = @src
      keys = []
      while true
        key =
          case src.getbyte(ss.pos)
          when DQUOTE then single_line_basic_string
          when SQUOTE then ss.skip(LITERAL_STRING) ? ss[1] : error("Invalid quoted key")
          else ss.scan(BARE_KEY) || error("Expected a key")
          end
        keys << (@symbolize_keys ? key.to_sym : key.freeze)
        return keys unless skip_spaces == DOT

        ss.pos += 1
        skip_spaces
      end
    end

    # Whitespace

    # Skips spaces and tabs; returns the next byte.
    def skip_spaces
      ss = @ss
      src = @src
      pos = ss.pos
      byte = src.getbyte(pos)
      return byte unless byte == SPACE || byte == TAB

      # A single space (`a = 1, b = 2`) is far more common than a run; skip it without a regex.
      byte = src.getbyte(pos + 1)
      if byte == SPACE || byte == TAB
        ss.skip(SPACES)
        src.getbyte(ss.pos)
      else
        ss.pos = pos + 1
        byte
      end
    end

    # Skips whitespace, newlines and comments; returns the next byte.
    def skip_gap
      ss = @ss
      src = @src
      while (byte = src.getbyte(ss.pos))
        if byte == HASH
          skip_comment
        elsif byte == SPACE && !GAP_START[src.getbyte(ss.pos + 1) || 0]
          ss.pos += 1
        elsif GAP_START[byte]
          ss.skip(WHITESPACE) || error("Carriage return without line feed")
        else
          return byte
        end
      end
      nil
    end

    def skip_comment
      ss = @ss
      unless ss.skip_until(COMMENT_BLOCK_END)
        ss.terminate
        return
      end
      return if @src.getbyte(ss.pos - 1) == NEWLINE

      ss.pos -= 1
      error("Control character in comment")
    end

    # Values

    def scalar(byte)
      ss = @ss
      case VALUE_START[byte || 0]
      when :basic_string then basic_string
      when :literal_string then literal_string
      when :digit then digit_value
      when :sign
        next_byte = @src.getbyte(ss.pos + 1)
        (next_byte == LOWER_I || next_byte == LOWER_N) ? float_keyword : number
      when :true_keyword then ss.skip(TRUE_KEYWORD) ? true : error("Invalid value")
      when :false_keyword then ss.skip(FALSE_KEYWORD) ? false : error("Invalid value")
      when :inf_or_nan then float_keyword
      else error(byte ? "Invalid value" : "Expected a value")
      end
    end

    # Parses the array or inline table opening at the current position. Enclosing
    # containers are kept on `stack` as (container, in_array, pending keys) triples.
    # `expecting_value` is true right after an opening bracket or a comma. In TOML 1.0
    # an inline table may only close there when it is still empty (no trailing comma).
    def container(byte)
      ss = @ss
      src = @src
      stack = []
      ss.pos += 1
      in_array = byte == LBRACKET
      current = in_array ? [] : {}
      keys = nil
      expecting_value = true

      while true
        if in_array
          byte = src.getbyte(ss.pos)
          byte = skip_gap if byte && GAP_START[byte]
          if expecting_value
            if byte == DQUOTE
              if ss.skip(STRING_ELEMENT)
                current << ss[1]
                next
              end
            elsif VALUE_START[byte || 0] == :digit && ss.skip(INTEGER_ELEMENT)
              current << ss[1].to_i
              next
            end
            if byte != RBRACKET
              if byte == LBRACKET || byte == LBRACE
                stack.push(current, true, nil)
                ss.pos += 1
                in_array = byte == LBRACKET
                current = in_array ? [] : {}
                next
              end
              current << scalar(byte)
              expecting_value = false
              next
            end
          elsif byte == COMMA
            ss.pos += 1
            expecting_value = true
            next
          elsif byte != RBRACKET
            error("Expected , or ] in array")
          end
        else
          # TOML 1.1 lets inline tables span lines. Plain spaces are left to the
          # cheaper paths below; skip_gap only runs before a line break or comment.
          if @inline_newlines
            byte = src.getbyte(ss.pos)
            skip_gap if byte && LINE_BREAK_OR_COMMENT[byte]
          end
          if expecting_value && ss.skip(INLINE_KEY_EQUALS)
            key = ss[1]
            key = @symbolize_keys ? key.to_sym : key.freeze
            byte = src.getbyte(ss.pos)
            if byte == LBRACKET || byte == LBRACE
              stack.push(current, false, [key])
              ss.pos += 1
              in_array = byte == LBRACKET
              current = in_array ? [] : {}
              next
            end
            conflict([key]) if current.key?(key)
            current[key] = scalar(byte)
            expecting_value = false
            next
          end
          byte = skip_spaces
          byte = skip_gap if @inline_newlines && byte && LINE_BREAK_OR_COMMENT[byte]
          if expecting_value
            if byte != RBRACE || !(@inline_newlines || current.empty?)
              keys = key_path
              error("Expected '=' in inline table") unless ss.skip(EQUALS)
              byte = src.getbyte(ss.pos)
              if byte == LBRACKET || byte == LBRACE
                stack.push(current, false, keys)
                ss.pos += 1
                in_array = byte == LBRACKET
                current = in_array ? [] : {}
                next
              end
              define(current, keys, scalar(byte))
              expecting_value = false
              next
            end
          elsif byte == COMMA
            ss.pos += 1
            expecting_value = true
            next
          elsif byte != RBRACE
            error("Expected , or } in inline table")
          end
        end

        # Close the current container and hand it to its parent.
        ss.pos += 1
        value = current
        return value if stack.empty?

        keys = stack.pop
        in_array = stack.pop
        current = stack.pop
        if in_array
          current << value
        else
          define(current, keys, value)
        end
        expecting_value = false
      end
    end

    def basic_string
      triple_quote?(DQUOTE) ? multiline_basic_string : single_line_basic_string
    end

    # Reads plain runs and escapes straight off the scanner: one match per run and
    # a table lookup per simple escape, instead of matching the whole string and
    # rescanning it with gsub.
    def single_line_basic_string
      ss = @ss
      src = @src
      ss.pos += 1
      out = nil
      while true
        segment = ss.scan(STRING_SEGMENT)
        out = out ? out << segment : segment
        byte = src.getbyte(ss.pos)
        if byte == DQUOTE
          ss.pos += 1
          return out
        end
        error("Unterminated string") unless byte == BACKSLASH

        append_escape(out, false)
      end
    end

    # Same scheme; quotes are counted to tell content quotes from the closing `"""`.
    def multiline_basic_string
      ss = @ss
      src = @src
      pos = ss.pos + 3
      byte = src.getbyte(pos)
      if byte == NEWLINE
        pos += 1
      elsif byte == CR && src.getbyte(pos + 1) == NEWLINE
        pos += 2
      end
      ss.pos = pos
      out = nil
      while true
        segment = ss.scan(MULTILINE_STRING_SEGMENT)
        out = out ? out << segment : segment
        pos = ss.pos
        byte = src.getbyte(pos)
        if byte == DQUOTE
          quotes = 1
          quotes += 1 while src.getbyte(pos + quotes) == DQUOTE
          if quotes < 3
            out << TRAILING_QUOTES[quotes]
            ss.pos = pos + quotes
          else
            extra = (quotes > 5) ? 2 : quotes - 3
            ss.pos = pos + 3 + extra
            return out << TRAILING_QUOTES[extra]
          end
        elsif byte == BACKSLASH
          append_escape(out, true)
        else
          error("Unterminated multi-line string")
        end
      end
    end

    # Appends the escape sequence at the current backslash to `out`.
    def append_escape(out, multiline)
      ss = @ss
      byte = @src.getbyte(ss.pos + 1)
      if byte && (char = @escapes[byte])
        ss.pos += 2
        out << char
      elsif ss.skip(UNICODE_ESCAPE)
        out << (ss[1] || ss[2]).to_i(16).chr(UTF_8)
      elsif @hex_escapes && ss.skip(HEX_ESCAPE)
        out << ss[1].to_i(16).chr(UTF_8)
      elsif !(multiline && ss.skip(LINE_ENDING_BACKSLASH))
        error("Invalid escape sequence")
      end
    end

    def literal_string
      ss = @ss
      if triple_quote?(SQUOTE)
        error("Unterminated multi-line literal string") unless ss.skip(MULTILINE_LITERAL_STRING)
        trim_leading_newline(multiline_content(ss[1], ss[2]))
      elsif ss.skip(LITERAL_STRING)
        ss[1]
      else
        error("Invalid or unterminated literal string")
      end
    end

    def triple_quote?(quote)
      pos = @ss.pos
      @src.getbyte(pos + 1) == quote && @src.getbyte(pos + 2) == quote
    end

    # Content plus the up to two quotes that end it (`'''a'''''` is `a''`).
    def multiline_content(content, quotes)
      quotes.empty? ? content : content << quotes
    end

    def trim_leading_newline(str)
      if str.start_with?("\n")
        str[1..]
      elsif str.start_with?("\r\n")
        str[2..]
      else
        str
      end
    end

    # LOCAL_TIME needs `HH:` and DATETIME `YYYY-`; the separator byte decides
    # which (if any) applies without a failing regex match.
    def date_or_time_ahead?
      pos = @ss.pos
      @src.getbyte(pos + 2) == COLON || @src.getbyte(pos + 4) == DASH
    end

    # The separator guards can fire on a short number followed by more lines
    # (`3\n\n[-]`), so a failed date/time match falls back to a number.
    def digit_value
      ss = @ss
      pos = ss.pos
      if @src.getbyte(pos + 2) == COLON && ss.skip(@local_time)
        LocalTime.new(ss[1], ss[2], seconds(ss[3]))
      elsif @src.getbyte(pos + 4) == DASH && ss.skip(@datetime)
        datetime(*ss.values_at(1, 2, 3, 4, 5, 6, 7))
      else
        number
      end
    end

    # INTEGER runs first because most numbers are integers; a following `.`, `e`
    # or `E` means it only matched the integer part of a FLOAT.
    def number
      ss = @ss
      src = @src
      pos = ss.pos
      if src.getbyte(pos) == ZERO && (base = NON_DECIMAL_BASES[src.getbyte(pos + 1)])
        text = ss.scan(NON_DECIMAL_INTEGER) || error("Invalid integer")
        return text.to_i(base)
      end
      text = ss.scan(INTEGER) || error("Invalid number")
      next_byte = src.getbyte(ss.pos)
      return text.to_i unless next_byte == DOT || next_byte == LOWER_E || next_byte == UPPER_E

      ss.pos = pos
      (ss.scan(FLOAT) || error("Invalid float")).to_f
    end

    def float_keyword
      text = @ss.scan(FLOAT_KEYWORD) || error("Invalid value")
      if text.end_with?("nan")
        Float::NAN
      else
        text.start_with?("-") ? -Float::INFINITY : Float::INFINITY
      end
    end

    # Fields are range-checked as Integers before Time.new, which would otherwise
    # silently roll an out-of-range day or 24:00:00 over.
    def datetime(year, month, day, hour, min, sec, offset)
      return LocalDate.new(year, month, day) if hour.nil?
      return LocalDateTime.new(year, month, day, hour, min, seconds(sec)) if offset.nil?

      year = year.to_i
      month = month.to_i
      day = day.to_i
      hour = hour.to_i
      min = min.to_i
      sec = seconds(sec)
      unless LocalDate.valid_date?(year, month, day) && hour < 24 && min < 60 && sec < 60
        raise ArgumentError, "Invalid Offset Date-Time: #{year}-#{month}-#{day}T#{hour}:#{min}:#{sec}#{offset}"
      end

      Time.new(year, month, day, hour, min, sec, (offset == "Z" || offset == "z") ? "+00:00" : offset)
    end

    # Fractional seconds are exact (`56.123` stays 56123/1000; a Float would make it
    # 56.122999...); whole seconds stay Integers, which Time handles fastest. TOML 1.1
    # may leave seconds out.
    def seconds(text)
      if text.nil?
        0
      elsif text.length == 2
        text.to_i
      else
        Rational(text)
      end
    end

    # Tables

    def open_table(keys)
      parent = header_parent(keys)
      key = keys.last
      table = parent[key]
      if table.nil?
        table = parent[key.freeze] = {}
        @kinds[table] = HEADER
      elsif @kinds[table] == IMPLICIT
        @kinds[table] = HEADER
      else
        conflict(keys)
      end
      @current = table
    end

    def open_array_of_tables(keys)
      parent = header_parent(keys)
      key = keys.last
      tables = parent[key]
      element = {}
      @kinds[element] = HEADER
      if tables.nil?
        tables = parent[key.freeze] = [element]
        @kinds[tables] = ARRAY_OF_TABLES
      elsif @kinds[tables] == ARRAY_OF_TABLES
        tables << element
      else
        conflict(keys)
      end
      @current = element
    end

    # Walks `[a.b.c]` up to `b`, creating implicit tables and descending into the
    # latest element of arrays of tables.
    def header_parent(keys)
      table = @root
      last = keys.length - 1
      i = 0
      while i < last
        key = keys[i]
        child = table[key]
        if child.nil?
          child = table[key.freeze] = {}
          @kinds[child] = IMPLICIT
        else
          case @kinds[child]
          when ARRAY_OF_TABLES then child = child.last
          when nil then conflict(keys)
          end
        end
        table = child
        i += 1
      end
      table
    end

    def define(table, keys, value)
      last = keys.length - 1
      i = 0
      while i < last
        key = keys[i]
        child = table[key]
        if child.nil?
          child = table[key] = {}
          @kinds[child] = DOTTED
        elsif @kinds[child] != DOTTED
          conflict(keys)
        end
        table = child
        i += 1
      end
      conflict(keys) if table.key?(keys[last])

      table[keys[last]] = value
    end

    # Errors

    def conflict(keys)
      raise ParseError, "Key #{keys.join(".")} is already defined"
    end

    def error(message)
      pos = @ss.pos
      before = @src.byteslice(0, pos)
      line_start = before.rindex("\n")
      column = pos - (line_start ? line_start + 1 : 0) + 1
      raise ParseError, "#{message} at line #{before.count("\n") + 1}, column #{column}"
    end
  end
end
