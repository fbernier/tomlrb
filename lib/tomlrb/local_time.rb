# frozen-string-literal: true

require 'forwardable'

module Tomlrb
  class LocalTime
    extend Forwardable

    def_delegators :time, :hour, :min, :sec, :usec, :nsec

    # Fields are validated here; the Time behind them is built on first use.
    def initialize(hour, min, sec)
      @hour = hour.to_i
      @min = min.to_i
      @sec = sec
      raise ArgumentError, "Invalid Local Time: #{hour}-#{min}-#{sec}" unless @hour < 24 && @min < 60 && sec.to_f < 60
    end

    # @param year [Integer]
    # @param month [Integer]
    # @param day [Integer]
    # @param offset see {LocalDateTime#to_time}
    # @return [Time] the time of the date specified by params
    def to_time(year, month, day, offset = '-00:00')
      Time.new(year, month, day, @hour, @min, @sec, offset)
    end

    def to_s
      frac = (@sec - sec)
      frac_str = frac.zero? ? '' : frac.to_s[1..-1]
      time.strftime('%T') << frac_str
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
