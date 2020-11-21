require 'forwardable'

module Tomlrb
  class LocalDate
    extend Forwardable

    def_delegators :@time, :year, :month, :day

    def initialize(year, month, day)
      @time = Time.new(year, month, day, 0, 0, 0, '-00:00')
    end

    def to_time(offset='-00:00')
      return @time if offset == '-00:00'
      Time.new(year, month, day, 0, 0, 0, offset)
    end

    def to_s
      @time.strftime('%F')
    end

    def ==(other)
      to_time == other.to_time
    end

    def inspect
      "#<#{self.class}: #{to_s}>"
    end
  end
end
