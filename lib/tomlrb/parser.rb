# frozen_string_literal: true

require "strscan"

module Tomlrb
  # Single-pass TOML 1.1 / 1.0 parser over a StringScanner.
  #
  # Costs that shape the code (CRuby 3.3, instructions): a regex call has about
  # 1000 fixed overhead, an anchored `[class]*` loop then costs ~80 per byte while
  # an unanchored search for a character class costs ~11 per byte, a capture
  # 600-800, a `getbyte` ~190 (~40 under YJIT). So the parser dispatches on bytes
  # through lookup tables, fuses the commonest shapes into one regex (`key =`,
  # a plain string or integer plus the rest of its line and any blank lines after
  # it, an array element or inline table value plus its comma), reads date and
  # time fields as bytes, and skips comments by searching for the character that
  # ends them. Arrays and inline tables use an explicit stack, so nesting depth is
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

    CTRL = '\x00-\x08\x0a-\x1f\x7f' # control characters, tab excluded
    EOL_SRC = "[ \\t]*(?:#[^#{CTRL}]*)?(?:(?:\\r?\\n[ \\t]*)+|\\z)"
    BARE_KEY_SRC = "[A-Za-z0-9_-]+"
    TABLE_NAME_SRC = "[ \\t]*(#{BARE_KEY_SRC}(?:\\.#{BARE_KEY_SRC})*)[ \\t]*"
    PLAIN_BASIC_STRING_SRC = %("([^"\\\\#{CTRL}]*)") # no escapes; captures the content
    PLAIN_LITERAL_STRING_SRC = "'([^'#{CTRL}]*)'"
    INTEGER_SRC = "[+-]?(?:0|[1-9](?:_?[0-9])*)"

    EOL = /#{EOL_SRC}/
    WHITESPACE = /(?:[ \t\n]|\r\n)+/
    SPACES = /[ \t]+/
    EQUALS = /[ \t]*=[ \t]*/
    # Searched for, not matched: where a block of comment lines ends. It stops at a
    # line break not followed by another comment line, or at a character no comment
    # may contain, so consecutive comment lines cost one call.
    COMMENT_BLOCK_END = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]|\r(?!\n)|\r?\n(?![ \t]*#)/

    BARE_KEY = /#{BARE_KEY_SRC}/
    KEY_EQUALS = /(#{BARE_KEY_SRC})[ \t]*=[ \t]*/
    INLINE_KEY_EQUALS = /[ \t]*(#{BARE_KEY_SRC})[ \t]*=[ \t]*/
    TABLE_HEADER = /\[#{TABLE_NAME_SRC}\]#{EOL_SRC}/
    ARRAY_TABLE_HEADER = /\[\[#{TABLE_NAME_SRC}\]\]#{EOL_SRC}/
    TABLE_CLOSE = /\]#{EOL_SRC}/
    ARRAY_TABLE_CLOSE = /\]\]#{EOL_SRC}/

    SIMPLE_BASIC_STRING_EOL = /#{PLAIN_BASIC_STRING_SRC}#{EOL_SRC}/
    # A plain string array element with its comma and the whitespace after it, or
    # the last element before `]` (closing after a value or after a trailing comma
    # is the same thing, so the loop needs no record of which it was). The leading
    # whitespace is atomic: giving it back a character at a time would rerun the
    # lookahead over the rest of it, quadratic in the run's length.
    ELEMENT_END = '(?>[ \t]*)(?:,[ \t]*(?:\r?\n[ \t]*)?|(?=[ \t\r\n]*\]))'
    STRING_ELEMENT = /#{PLAIN_BASIC_STRING_SRC}#{ELEMENT_END}/
    # The same for an integer; the separator rules out a float or date continuing it.
    INTEGER_ELEMENT = /(#{INTEGER_SRC})#{ELEMENT_END}/
    STRING_SEGMENT = /[^"\\#{CTRL}]*/
    # Searched for, not matched: what ends a multi-line basic string's plain run
    # (three quotes, a backslash, a control character or a lone CR). Single and
    # double quotes stay inside the run.
    MULTILINE_STRING_STOP = /"""|[\\\x00-\x08\x0b\x0c\x0e-\x1f\x7f]|\r(?!\n)/
    UNICODE_ESCAPE = /\\(?:u([0-9A-Fa-f]{4})|U([0-9A-Fa-f]{8}))/
    # A backslash ending a line drops the line break and all whitespace after it.
    LINE_ENDING_BACKSLASH = /\\[ \t]*\r?\n(?:[ \t\n]|\r\n)*/
    LITERAL_STRING = /#{PLAIN_LITERAL_STRING_SRC}/
    LITERAL_STRING_EOL = /#{PLAIN_LITERAL_STRING_SRC}#{EOL_SRC}/
    # The same for a multi-line literal string, which has no escapes.
    MULTILINE_LITERAL_STRING_STOP = /'''|[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]|\r(?!\n)/

    # What follows a float's integer part: a fraction, an exponent, or both.
    FLOAT_TAIL_SRC = "(?:\\.[0-9](?:_?[0-9])*(?:[eE][+-]?[0-9](?:_?[0-9])*)?|[eE][+-]?[0-9](?:_?[0-9])*)"
    FLOAT_SRC = "#{INTEGER_SRC}#{FLOAT_TAIL_SRC}"
    INTEGER = /#{INTEGER_SRC}/
    INTEGER_EOL = /(#{INTEGER_SRC})#{EOL_SRC}/
    FLOAT_TAIL = /#{FLOAT_TAIL_SRC}/
    FLOAT_EOL = /(#{FLOAT_SRC})#{EOL_SRC}/
    # A plain string, integer or boolean inline table value together with its
    # comma, or up to the `}` after it; the caller tells which by the last byte
    # consumed. A float, date or anything else continuing the value fails it.
    INLINE_VALUE_END = '(?>[ \t]*)(?:,|(?=\}))'
    INLINE_STRING = /#{PLAIN_BASIC_STRING_SRC}#{INLINE_VALUE_END}/
    INLINE_INTEGER = /(#{INTEGER_SRC})#{INLINE_VALUE_END}/
    INLINE_TRUE = /true#{INLINE_VALUE_END}/
    INLINE_FALSE = /false#{INLINE_VALUE_END}/
    NON_DECIMAL_INTEGER = /0(?:x[0-9A-Fa-f](?:_?[0-9A-Fa-f])*|o[0-7](?:_?[0-7])*|b[01](?:_?[01])*)/
    FLOAT_KEYWORD = /[+-]?(?:inf|nan)/
    TRUE_KEYWORD = /true/
    FALSE_KEYWORD = /false/
    TRUE_EOL = /true#{EOL_SRC}/
    FALSE_EOL = /false#{EOL_SRC}/
    # No captures: the fields sit at fixed offsets from the match start and are
    # read as bytes (see #datetime), saving a String and 600-800 instructions each.
    TIME_SRC_V1_0 = '\d{2}:\d{2}:\d{2}(?:\.\d+)?'
    TIME_SRC_V1_1 = '\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?' # seconds optional
    LOCAL_TIME_V1_0 = /#{TIME_SRC_V1_0}/
    LOCAL_TIME_V1_1 = /#{TIME_SRC_V1_1}/
    DATETIME_V1_0 = /\d{4}-\d{2}-\d{2}(?:[Tt ]#{TIME_SRC_V1_0}(?:[Zz]|[-+]\d{2}:\d{2})?)?/
    DATETIME_V1_1 = /\d{4}-\d{2}-\d{2}(?:[Tt ]#{TIME_SRC_V1_1}(?:[Zz]|[-+]\d{2}:\d{2})?)?/

    def self.byte_table(classes)
      table = Array.new(256)
      classes.each { |chars, klass| chars.each_byte { |b| table[b] = klass } }
      table.freeze
    end

    # Escape character byte -> its value.
    ESCAPES_V1_0 = byte_table("b" => "\b", "t" => "\t", "n" => "\n", "f" => "\f", "r" => "\r", '"' => '"', "\\" => "\\")
    ESCAPES_V1_1 = ESCAPES_V1_0.dup.tap { |table| table["e".ord] = "\e" }.freeze
    HEX_ESCAPE = /\\x([0-9A-Fa-f]{2})/

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
    PLUS = "+".ord
    UPPER_Z = "Z".ord
    LOWER_Z = "z".ord
    UPPER_E = "E".ord
    LOWER_I = "i".ord
    LOWER_N = "n".ord
    LOWER_T = "t".ord
    LOWER_F = "f".ord
    NON_DECIMAL_BASES = {"x".ord => 16, "o".ord => 8, "b".ord => 2}.freeze

    GAP_START = byte_table(" \t\n\r#" => true)
    LINE_BREAK_OR_COMMENT = byte_table("\n\r#" => true)
    # Regex for an inline table value that can be fused with its separator.
    INLINE_SCALAR = byte_table('"' => INLINE_STRING, "0123456789+-" => INLINE_INTEGER, "t" => INLINE_TRUE,
      "f" => INLINE_FALSE)
    NUMBER_START = byte_table("0123456789+-" => true)
    VALUE_START = byte_table(
      '"' => :basic_string, "'" => :literal_string, "0123456789" => :digit, "+-" => :sign,
      "t" => :true_keyword, "f" => :false_keyword, "in" => :inf_or_nan, "[" => :array, "{" => :inline_table
    )

    # @param version ["1.1", "1.0"] the TOML spec to follow; "1.0" also rejects what 1.1 added
    def initialize(src, version: "1.1", symbolize_keys: false, **)
      spec = SPECS.fetch(version) do
        raise ArgumentError, "Unsupported TOML version #{version.inspect} (supported: #{SPECS.keys.join(", ")})"
      end
      if src.encoding != Encoding::UTF_8
        src = (src.encoding == Encoding::BINARY) ? src.dup.force_encoding(Encoding::UTF_8) : src.encode(Encoding::UTF_8)
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
        if GAP_START[byte]
          byte = skip_gap
          break unless byte
        end
        (byte == LBRACKET) ? header : key_value
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
      when :sign
        # `+inf` and `-nan` fail both and fall through to `scalar`.
        return ss[1].to_i if ss.skip(INTEGER_EOL)
        return ss[1].to_f if ss.skip(FLOAT_EOL)
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
        name = ss[1]
        keys = name.include?(".") ? name.split(".") : [name]
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
    # containers are kept on `stack` as (container, pending keys) pairs, keys nil
    # for an array; it stays nil for a flat container, the common case.
    # `expecting_value` is true right after an opening bracket or a comma. In TOML 1.0
    # an inline table may only close there when it is still empty (no trailing comma).
    def container(byte)
      ss = @ss
      src = @src
      stack = nil
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
            elsif NUMBER_START[byte || 0] && ss.skip(INTEGER_ELEMENT)
              current << ss[1].to_i
              next
            end
            if byte != RBRACKET
              if byte == LBRACKET || byte == LBRACE
                (stack ||= []).push(current, nil)
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
              (stack ||= []).push(current, [key])
              ss.pos += 1
              in_array = byte == LBRACKET
              current = in_array ? [] : {}
              next
            end
            conflict([key]) if current.key?(key)
            if (fused = INLINE_SCALAR[byte || 0]) && ss.skip(fused)
              current[key] =
                case byte
                when DQUOTE then ss[1]
                when LOWER_T then true
                when LOWER_F then false
                else ss[1].to_i
                end
              # The separator either took a comma or stopped before `}`.
              expecting_value = src.getbyte(ss.pos - 1) == COMMA
            else
              current[key] = scalar(byte)
              expecting_value = false
            end
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
                (stack ||= []).push(current, keys)
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
        return value if stack.nil? || stack.empty?

        keys = stack.pop
        current = stack.pop
        if (in_array = keys.nil?)
          current << value
        else
          define(current, keys, value)
        end
        expecting_value = false
      end
    end

    def basic_string
      triple_quote?(DQUOTE) ? multiline_string(DQUOTE, MULTILINE_STRING_STOP) : single_line_basic_string
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

    # The multi-line string, basic (`quote` is DQUOTE) or literal, opening at the
    # current position. Plain runs, quotes short of three included, are found by
    # searching for what ends them: unlike an anchored match, the search neither
    # walks every byte through the regex VM nor grows Onigmo's stack with the run
    # (48 MB for a 1 MB string). Up to two quotes before the closing three are
    # content (`'''a'''''` is `a''`).
    def multiline_string(quote, stop)
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
        start = ss.pos
        unless ss.skip_until(stop)
          ss.terminate
          unterminated_multiline_string(quote)
        end
        pos = ss.pos - ss.matched_size
        byte = src.getbyte(pos)
        if byte == quote
          pos += 1 if src.getbyte(pos + 3) == quote
          pos += 1 if src.getbyte(pos + 3) == quote
        end
        segment = src.byteslice(start, pos - start)
        out = out ? out << segment : segment
        if byte == quote
          ss.pos = pos + 3
          return out
        end

        ss.pos = pos
        unterminated_multiline_string(quote) unless byte == BACKSLASH
        append_escape(out, true)
      end
    end

    def unterminated_multiline_string(quote)
      error((quote == DQUOTE) ? "Unterminated multi-line string" : "Unterminated multi-line literal string")
    end

    # Appends the escape sequence at the current backslash to `out`.
    def append_escape(out, multiline)
      ss = @ss
      byte = @src.getbyte(ss.pos + 1)
      if byte && (char = @escapes[byte])
        ss.pos += 2
        out << char
      elsif ss.skip(UNICODE_ESCAPE)
        out << (ss[1] || ss[2]).to_i(16).chr(Encoding::UTF_8)
      elsif @hex_escapes && ss.skip(HEX_ESCAPE)
        out << ss[1].to_i(16).chr(Encoding::UTF_8)
      elsif !(multiline && ss.skip(LINE_ENDING_BACKSLASH))
        error("Invalid escape sequence")
      end
    end

    def literal_string
      ss = @ss
      if triple_quote?(SQUOTE)
        multiline_string(SQUOTE, MULTILINE_LITERAL_STRING_STOP)
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
        LocalTime.new(two_digits(pos), two_digits(pos + 3), seconds(pos + 5, ss.pos))
      elsif @src.getbyte(pos + 4) == DASH && ss.skip(@datetime)
        datetime(pos, ss.pos)
      else
        number
      end
    end

    # INTEGER runs first because most numbers are integers; a following `.`, `e`
    # or `E` means it only matched the integer part of a float, whose tail is then
    # scanned from there. Nothing is materialized until the kind is known.
    def number
      ss = @ss
      src = @src
      pos = ss.pos
      if src.getbyte(pos) == ZERO && (base = NON_DECIMAL_BASES[src.getbyte(pos + 1)])
        text = ss.scan(NON_DECIMAL_INTEGER) || error("Invalid integer")
        return text.to_i(base)
      end
      error("Invalid number") unless ss.skip(INTEGER)
      next_byte = src.getbyte(ss.pos)
      return ss.matched.to_i unless next_byte == DOT || next_byte == LOWER_E || next_byte == UPPER_E

      unless ss.skip(FLOAT_TAIL)
        ss.pos = pos
        error("Invalid float")
      end
      src.byteslice(pos, ss.pos - pos).to_f
    end

    def float_keyword
      text = @ss.scan(FLOAT_KEYWORD) || error("Invalid value")
      if text.end_with?("nan")
        Float::NAN
      else
        text.start_with?("-") ? -Float::INFINITY : Float::INFINITY
      end
    end

    # The date-time matched from `pos` to `stop`. Fields are range-checked as
    # Integers before Time.new, which would otherwise silently roll an
    # out-of-range day or 24:00:00 over.
    def datetime(pos, stop)
      src = @src
      year = two_digits(pos) * 100 + two_digits(pos + 2)
      month = two_digits(pos + 5)
      day = two_digits(pos + 8)
      return LocalDate.new(year, month, day) if stop == pos + 10

      hour = two_digits(pos + 11)
      min = two_digits(pos + 14)
      last = src.getbyte(stop - 1)
      if last == UPPER_Z || last == LOWER_Z
        time_end = stop - 1
        offset = 0 # the same Time as "+00:00", without parsing it
      elsif (sign = src.getbyte(stop - 6)) == PLUS || sign == DASH
        time_end = stop - 6
        offset = src.byteslice(time_end, 6)
      else
        return LocalDateTime.new(year, month, day, hour, min, seconds(pos + 16, stop))
      end

      sec = seconds(pos + 16, time_end)
      unless LocalDate.valid_date?(year, month, day) && hour < 24 && min < 60 && sec < 60
        raise ArgumentError, "Invalid Offset Date-Time: #{src.byteslice(pos, stop - pos)}"
      end

      Time.new(year, month, day, hour, min, sec, offset)
    end

    def two_digits(pos)
      src = @src
      src.getbyte(pos) * 10 + src.getbyte(pos + 1) - 528 # "00" is 48 * 10 + 48
    end

    # Seconds of a time whose minutes end at `pos` and which ends at `stop`: none
    # (TOML 1.1 `hh:mm`), `:ss`, or `:ss.fraction`. Fractions are exact (`56.123`
    # stays 56123/1000; a Float would make it 56.122999...); whole seconds stay
    # Integers, which Time handles fastest.
    def seconds(pos, stop)
      if stop == pos
        0
      elsif stop == pos + 3
        two_digits(pos + 1)
      else
        Rational(@src.byteslice(pos + 1, stop - pos - 1))
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

    # Columns count characters; the scanner position is a byte offset.
    def error(message)
      pos = @ss.pos
      before = @src.byteslice(0, pos)
      line_start = before.byterindex("\n")
      line_start = line_start ? line_start + 1 : 0
      column = before.byteslice(line_start, pos - line_start).length + 1
      raise ParseError, "#{message} at line #{before.count("\n") + 1}, column #{column}"
    end
  end
end
