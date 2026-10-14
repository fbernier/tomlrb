# frozen_string_literal: true

require "json"
require "time"

# Converts a parsed document to toml-test's JSON description: tables become
# objects, arrays arrays, and every value a {"type" => ..., "value" => String}.
# Used by bin/toml-test-decoder for the official runner, and by the compliance
# test, which compares descriptions the way that runner does (.normalize).
module TomlTestJSON
  module_function

  def describe(value)
    case value
    when Hash then value.to_h { |key, child| [key.to_s, describe(child)] }
    when Array then value.map { |child| describe(child) }
    when String then leaf("string", value)
    when Integer then leaf("integer", value.to_s)
    when Float then leaf("float", float(value))
    when true, false then leaf("bool", value.to_s)
    when Time then leaf("datetime", datetime(value))
    when Tomlrb::LocalDateTime then leaf("datetime-local", value.to_s)
    when Tomlrb::LocalDate then leaf("date-local", value.to_s)
    when Tomlrb::LocalTime then leaf("time-local", value.to_s)
    else raise TypeError, "unexpected #{value.class} in parse result"
    end
  end

  # Maps a description to comparable Ruby values: numbers and offset date-times
  # by value, local date-times and times without trailing fractional zeros.
  def normalize(node)
    case node
    when Array then node.map { |child| normalize(child) }
    when Hash
      return node.transform_values { |child| normalize(child) } unless node.keys.sort == %w[type value]

      type, value = node.values_at("type", "value")
      [type, normalize_value(type, value)]
    end
  end

  def normalize_value(type, value)
    case type
    when "integer" then Integer(value, 10)
    when "float"
      case value.delete_prefix("+")
      when "nan", "-nan" then :nan
      when "inf" then Float::INFINITY
      when "-inf" then -Float::INFINITY
      else Float(value)
      end
    when "datetime" then Time.iso8601(value.tr("tz ", "TZT")).utc
    when "datetime-local", "time-local" then value.tr("t ", "TT").sub(/(\.\d*?)0+\z/, '\1').delete_suffix(".")
    else value
    end
  end

  def leaf(type, value)
    {"type" => type, "value" => value}
  end

  def float(value)
    return "nan" if value.nan?
    return value.positive? ? "inf" : "-inf" if value.infinite?

    value.to_s
  end

  def datetime(time)
    fraction = time.subsec.zero? ? "" : format(".%09d", time.nsec).sub(/0+\z/, "")
    offset = time.utc? ? "Z" : time.strftime("%:z")
    time.strftime("%Y-%m-%dT%H:%M:%S") + fraction + offset
  end
end
