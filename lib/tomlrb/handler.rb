module Tomlrb
  class Handler
    attr_reader :output

    def initialize
      @output = {}
      @current = @output
      @stack = []
    end

    def set_context(identifiers, is_array_of_tables: false)
      @current = @output

      deal_with_array_of_table(identifiers, is_array_of_tables) do |identifiers|
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

    def deal_with_array_of_table(identifiers, is_array_of_tables)
      identifiers.map!{|n| n.gsub("\"", '')}
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

    def start_(type)
      push([type])
    end

    def end_(type)
      array = []
      while (value = @stack.pop) != [type]
        raise if value.nil?
        array.unshift(value)
      end
      array
    end
  end
end
