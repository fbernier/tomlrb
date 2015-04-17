module Tomlrb
  class StringUtils

    def self.multiline_replacements(str)
      strip_spaces(str).gsub(/\\\n\s+/, '')
    end

    def self.replace_escaped_chars(str)
      str
        .gsub(/\\n/, "\n")
        .gsub(/\\0/, "\0")
        .gsub(/\\t/, "\t")
        .gsub(/\\r/, "\r")
        .gsub(/\\\"/, '"')
        .gsub(/\\\\/, '\\')
    end

    def self.strip_spaces(str)
      str[0] = '' if str[0] == "\n"
      str
    end
  end
end
