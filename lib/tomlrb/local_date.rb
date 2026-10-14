# frozen-string-literal: true

module Tomlrb
  class LocalDate
    DAYS_IN_MONTH = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

    # @return [Boolean] whether year, month and day (Integers) name a real calendar day
    def self.valid_date?(year, month, day)
      return false unless month >= 1 && month <= 12 && day >= 1

      day <= DAYS_IN_MONTH[month] ||
        (month == 2 && day == 29 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)))
    end

    attr_reader :year, :month, :day

    # The Time behind #to_time is built on first use: parsing creates many of these
    # and building a Time costs more than validating the fields.
    def initialize(year, month, day)
      @year = year.to_i
      @month = month.to_i
      @day = day.to_i
      raise ArgumentError, "Invalid Local Date: #{year}-#{month}-#{day}" unless LocalDate.valid_date?(@year, @month, @day)
    end

    # @param offset see {LocalDateTime#to_time}
    # @return [Time] 00:00:00 of the date
    def to_time(offset = '-00:00')
      return @time ||= Time.utc(@year, @month, @day, 0, 0, 0) if offset == '-00:00'

      Time.new(@year, @month, @day, 0, 0, 0, offset)
    end

    def to_s
      format('%04d-%02d-%02d', @year, @month, @day)
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
