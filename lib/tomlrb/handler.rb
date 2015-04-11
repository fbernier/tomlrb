module Tomlrb
  class Handler
    attr_reader :output

    def initialize
      @output = Hash.new { |h, k| h[k] = {} }
      @current = @output
      @stack = []
    end

    def set_context(name)
      @current = @output
      name.split('.').each do |key|
        @current[key] ||= {}
        @current = @current[key]
      end
    end

    def assign(k)
      @current[k] = @stack.pop
    end

    def push(o)
      @stack << o
    end

    def start_array
      push([:array])
    end

    def end_array
      array = []
      while (value = @stack.pop) != [:array]
        raise if value.nil?
        array.unshift(value)
      end
      push(array)
    end
  end
end
