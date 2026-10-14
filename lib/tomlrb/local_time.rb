# frozen_string_literal: true

require "forwardable"

module Tomlrb
  # A TOML local time (no date, no offset), e.g. `07:32:00.999999`.
  class LocalTime
    extend Forwardable

    def_delegators :time, :hour, :min, :sec, :usec, :nsec

    # @return [String] `.` and the digits of a fractional second count (`""` if whole)
    def self.fraction(seconds)
      fraction = seconds - seconds.floor
      fraction.zero? ? "" : format("%.9f", fraction)[1..].sub(/0+\z/, "")
    end

    # Fields are validated here; the Time behind them is built on first use.
    #
    # @param sec [Integer, Rational, Float] seconds, fraction included
    def initialize(hour, min, sec)
      @hour = hour.to_i
      @min = min.to_i
      @sec = sec
      raise ArgumentError, "Invalid Local Time: #{hour}:#{min}:#{sec}" unless @hour < 24 && @min < 60 && sec < 60
    end

    # @param offset see {LocalDateTime#to_time}
    # @return [Time] this time on the given day
    def to_time(year, month, day, offset = "-00:00")
      Time.new(year, month, day, @hour, @min, @sec, offset)
    end

    def to_s
      time.strftime("%T") << LocalTime.fraction(@sec)
    end

    def ==(other)
      other.is_a?(self.class) &&
        time == other.to_time(0, 1, 1)
    end

    def inspect
      "#<#{self.class}: #{self}>"
    end

    private

    def time
      @time ||= Time.utc(0, 1, 1, @hour, @min, @sec)
    end
  end
end
