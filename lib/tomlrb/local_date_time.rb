# frozen-string-literal: true

require 'forwardable'
require 'tomlrb/local_date'

module Tomlrb
  class LocalDateTime
    extend Forwardable

    def_delegators :to_time, :year, :month, :day, :hour, :min, :sec, :usec, :nsec

    # Fields are validated here; the Time behind them is built on first use, which
    # matters most for fractional seconds (a Float becomes an exact Rational).
    def initialize(year, month, day, hour, min, sec) # rubocop:disable Metrics/ParameterLists
      @year = year.to_i
      @month = month.to_i
      @day = day.to_i
      @hour = hour.to_i
      @min = min.to_i
      @sec = sec
      unless LocalDate.valid_date?(@year, @month, @day) && @hour < 24 && @min < 60 && sec.to_f < 60
        raise ArgumentError, "Invalid Local Date-Time: #{year}-#{month}-#{day}T#{hour}:#{min}:#{sec}"
      end
    end

    # @param offset [String, Symbol, Numeric, nil] time zone offset.
    #   * when +String+, must be '+HH:MM' format, '-HH:MM' format, 'UTC', 'A'..'I' or 'K'..'Z'. Arguments excluding '+-HH:MM' are supporeted at Ruby >= 2.7.0
    #   * when +Symbol+, must be +:dst+(for summar time for local) or +:std+(for standard time).
    #   * when +Numeric+, it is time zone offset in second.
    #   * when +nil+, local time zone offset is used.
    # @return [Time]
    def to_time(offset = '-00:00')
      return @time ||= Time.utc(@year, @month, @day, @hour, @min, @sec) if offset == '-00:00'

      Time.new(@year, @month, @day, @hour, @min, @sec, offset)
    end

    def to_s
      frac = (@sec - sec)
      frac_str = frac.zero? ? '' : frac.to_s[1..-1]
      to_time.strftime('%FT%T') << frac_str
    end

    def ==(other)
      other.is_a?(self.class) &&
        to_time == other.to_time
    end

    def inspect
      "#<#{self.class}: #{self}>"
    end
  end
end
