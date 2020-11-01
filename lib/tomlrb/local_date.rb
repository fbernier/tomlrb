module Tomlrb
  class LocalDate
    def initialize(year, month, day)
      @time = Time.new(year, month, day, 0, 0, 0, '-00:00')
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

    def to_time(offset='-00:00')
      return @time if offset == '-00:00'
      Time.new(@time.year, @time.month, @time.day, 0, 0, 0, offset)
    end

    def to_s
      @time.strftime('%F')
    end
  end
end
