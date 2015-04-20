module Tomlrb
  class Handler
    attr_reader :output

    def initialize(**options)
      @output = {}
      @current = @output
      @stack = []
      @symbolize_keys = options[:symbolize_keys]
    end

    def set_context(identifiers, is_array_of_tables: false)
      @current = @output

      deal_with_array_of_tables(identifiers, is_array_of_tables) do |identifierz|
        identifierz.each do |k|
          k = k.to_sym if @symbolize_keys
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

    def deal_with_array_of_tables(identifiers, is_array_of_tables)
      identifiers.map!{|n| n.gsub("\"", '')}
      last_identifier = identifiers.pop if is_array_of_tables

      yield(identifiers)

      if is_array_of_tables
        last_identifier = last_identifier.to_sym if @symbolize_keys
        @current[last_identifier] ||= []
        @current[last_identifier] << {}
        @current = @current[last_identifier].last
      end
    end

    def assign(k)
      k = k.to_sym if @symbolize_keys
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
