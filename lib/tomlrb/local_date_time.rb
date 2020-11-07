module Tomlrb
  class LocalDateTime
    def initialize(year, month, day, hour, min, sec)
      @time = Time.new(year, month, day, hour, min, sec, '-00:00')
      @sec = sec
    end

    def year
      @time.year
    end

    def month
      @time.month
    end
    alias mon month

    def day
      @time.day
    end

    def hour
      @time.hour
    end

    def min
      @time.min
    end

    def sec
      @time.sec
    end

    def usec
      @time.usec
    end

    def nsec
      @time.nsec
    end

    # @param offset [String, Symbol, Numeric, nil] time zone offset.
    #   * when +String+, must be '+HH:MM' format, '-HH:MM' format, 'UTC', 'A'..'I' or 'K'..'Z'. Arguments excluding '+-HH:MM' are supporeted at Ruby >= 2.7.0
    #   * when +Symbol+, must be +:dst+(for summar time for local) or +:std+(for standard time).
    #   * when +Numeric+, it is time zone offset in second.
    #   * when +nil+, local time zone offset is used.
    # @return [Time]
    def to_time(offset='-00:00')
      return @time if offset == '-00:00'
      Time.new(@time.year, @time.month, @time.day, @time.hour, @time.min, @sec, offset)
    end

    def to_s
      frac = (@sec - sec)
      frac_str = frac == 0 ? '' : "#{frac.to_s[1..-1]}"
      @time.strftime("%FT%T") << frac_str
    end

    def ==(other)
      to_time == other.to_time
    end

    def inspect
      "#<#{self.class}: #{to_s}>"
    end
  end
end
