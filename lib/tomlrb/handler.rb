module Tomlrb
  class Handler
    attr_reader :stack

    def initialize
      @output = Hash.new {|h, k| h[k] = {} }
      @current = @output
      @stack = []
    end

    def set_context(name)
      @current = @output[name]
      @context = name
    end

    def assign(k)
      @current[k] = @stack.pop
    end

    def start_array
      push [:array]
    end

    def end_array
      array = []
      while (value = @stack.pop) != [:array]
        raise if value.nil?
        array.unshift(value)
      end
      push(array)
    end

    def push(o)
      @stack << o
    end

    def result
      @output
    end

  end
end
