# frozen_string_literal: true

require_relative "test_helper"

describe Tomlrb::LocalDateTime do
  subject { Tomlrb::LocalDateTime.new("1979", "05", "27", "00", "32", 0.999999r) }

  it "keeps the fractional part exactly" do
    _(subject.to_s).must_equal "1979-05-27T00:32:00.999999"
    _(subject.usec).must_equal 999_999
  end

  it "rejects fields out of range" do
    _ { Tomlrb::LocalDateTime.new(1979, 5, 27, 24, 0, 0) }.must_raise ArgumentError
    _ { Tomlrb::LocalDateTime.new(1979, 5, 27, 0, 0, 60) }.must_raise ArgumentError
  end

  describe "#to_time" do
    it "returns a Time with zero offset" do
      _(subject.to_time).must_equal Time.new(1979, 5, 27, 0, 32, 0.999999r, "+00:00")
    end

    it "can change time zone by offset" do
      _(subject.to_time("+09:00")).must_equal Time.new(1979, 5, 27, 0, 32, 0.999999r, "+09:00")
    end
  end
end

describe Tomlrb::LocalDate do
  subject { Tomlrb::LocalDate.new("1979", "05", "27") }

  it "can initialize with year, month and day" do
    _(subject.to_s).must_equal "1979-05-27"
  end

  it "raises error for invalid date" do
    _ { Tomlrb::LocalDate.new("2100", "02", "29") }.must_raise ArgumentError
    _(Tomlrb::LocalDate.new("2000", "02", "29").day).must_equal 29
  end

  describe "#to_time" do
    it "has 00:00:00 as time part" do
      _(subject.to_time).must_equal Time.new(1979, 5, 27, 0, 0, 0, "+00:00")
    end

    it "can change time zone by offset" do
      _(subject.to_time("+09:00")).must_equal Time.new(1979, 5, 27, 0, 0, 0, "+09:00")
    end
  end
end

describe Tomlrb::LocalTime do
  subject { Tomlrb::LocalTime.new("00", "32", 0.999999r) }

  it "keeps the fractional part exactly" do
    _(subject.to_s).must_equal "00:32:00.999999"
    _(subject.usec).must_equal 999_999
  end

  describe "#to_time" do
    it "requires date part" do
      _(subject.to_time(1979, 5, 27)).must_equal Time.new(1979, 5, 27, 0, 32, 0.999999r, "+00:00")
    end

    it "can change time zone with offset" do
      _(subject.to_time(1979, 5, 27, "+09:00")).must_equal Time.new(1979, 5, 27, 0, 32, 0.999999r, "+09:00")
    end
  end
end
