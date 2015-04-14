module Tomlrb
  class Handler
    attr_reader :output

    def initialize
      @output = {}
      @current = @output
      @stack = []
    end

    def set_context(name, is_array_of_tables: false, is_inline_context: false)
      @current = @output unless is_inline_context

      deal_with_array_of_table(name, is_array_of_tables) do |identifiers|
        identifiers.each do |k|
          if @current[k].is_a?(Array)
            @current[k] << {} if @current[k].empty?
            @current = @current[k].last
          else
            @current[k] ||= {}
            @current = @current[k]
          end
        end
      end
    end

    def deal_with_array_of_table(name, is_array_of_tables)
      identifiers = name.split('.')
      last_identifier = identifiers.pop if is_array_of_tables

      yield(identifiers)

      if is_array_of_tables
        @current[last_identifier] ||= []
        @current[last_identifier] << {}
        @current = @current[last_identifier].last
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
