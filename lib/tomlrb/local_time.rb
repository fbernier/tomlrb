# frozen_string_literal: true

require "forwardable"

module Tomlrb
  # A TOML local time (no date, no offset), e.g. `07:32:00.999999`.
  class LocalTime
    extend Forwardable

    attr_reader :hour, :min

    def_delegators :time, :sec, :usec, :nsec

    # @return [String] `hh:mm:ss`, plus `.` and the fraction digits if `sec` has any
    def self.format(hour, min, sec)
      whole = sec.floor
      fraction = sec - whole
      text = Kernel.format("%02d:%02d:%02d", hour, min, whole)
      fraction.zero? ? text : text << Kernel.format("%.9f", fraction)[1..].sub(/0+\z/, "")
    end

    # Fields are validated here; the Time behind them is built on first use.
    #
    # @param sec [Integer, Rational, Float] seconds, fraction included
    def initialize(hour, min, sec)
      @hour = hour.to_i
      @min = min.to_i
      @sec = sec
      raise ArgumentError, "Invalid Local Time: #{self}" unless @hour < 24 && @min < 60 && sec < 60
    end

    # @param offset see {LocalDateTime#to_time}
    # @return [Time] this time on the given day
    def to_time(year, month, day, offset = "-00:00")
      Time.new(year, month, day, @hour, @min, @sec, offset)
    end

    def to_s
      LocalTime.format(@hour, @min, @sec)
    end

    def ==(other)
      other.is_a?(self.class) && @hour == other.hour && @min == other.min && @sec == other.seconds
    end

    def inspect
      "#<#{self.class}: #{self}>"
    end

    protected

    # Seconds with their fraction; #sec is the whole part only, like Time#sec.
    def seconds = @sec

    private

    def time
      @time ||= Time.utc(0, 1, 1, @hour, @min, @sec)
    end
  end
end
