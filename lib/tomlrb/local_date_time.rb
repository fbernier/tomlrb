# frozen_string_literal: true

require "forwardable"
require_relative "local_date"
require_relative "local_time"

module Tomlrb
  # A TOML local date-time (no offset), e.g. `1979-05-27T07:32:00.999999`.
  class LocalDateTime
    extend Forwardable

    attr_reader :year, :month, :day, :hour, :min

    def_delegators :to_time, :sec, :usec, :nsec

    # Fields are validated here; the Time behind them is built on first use.
    #
    # @param sec [Integer, Rational, Float] seconds, fraction included
    def initialize(year, month, day, hour, min, sec) # rubocop:disable Metrics/ParameterLists
      @year = year.to_i
      @month = month.to_i
      @day = day.to_i
      @hour = hour.to_i
      @min = min.to_i
      @sec = sec
      raise ArgumentError, "Invalid Local Date-Time: #{self}" unless
        LocalDate.valid_date?(@year, @month, @day) && @hour < 24 && @min < 60 && sec < 60
    end

    # @param offset [String, Integer, nil] UTC offset as accepted by Time.new
    #   ("+09:00", "UTC", "Z", seconds east of UTC, or nil for the local zone)
    # @return [Time] this date-time at the given offset (UTC by default)
    def to_time(offset = "-00:00")
      return @time ||= Time.utc(@year, @month, @day, @hour, @min, @sec) if offset == "-00:00"

      Time.new(@year, @month, @day, @hour, @min, @sec, offset)
    end

    def to_s
      format("%04d-%02d-%02dT", @year, @month, @day) << LocalTime.format(@hour, @min, @sec)
    end

    def ==(other)
      other.is_a?(self.class) && @year == other.year && @month == other.month && @day == other.day &&
        @hour == other.hour && @min == other.min && @sec == other.seconds
    end

    def inspect
      "#<#{self.class}: #{self}>"
    end

    protected

    # Seconds with their fraction; #sec is the whole part only, like Time#sec.
    def seconds = @sec
  end
end
