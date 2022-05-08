require 'minitest_helper'
require 'pathname'
require 'json'
require 'yaml'

EXPONENTIAL_NOTATIONS = %w[
  values/spec-float-4.yaml
  values/spec-float-5.yaml
  values/spec-float-6.yaml
  values/spec-float-9.yaml
]

UNDERSCORE_NUMBERS = %w[
  values/spec-float-8.yaml
]

RATIONAL_TIME = %w[
  values/spec-date-time-3.yaml
  values/spec-date-time-5.yaml
  values/spec-date-time-6.yaml
]

INT_KEY = %w[
  values/spec-key-value-pair-9.yaml
]

describe Tomlrb::Parser do
  tests_dirs = [
    File.join(__dir__, '../toml-spec-tests'),
    File.join(__dir__, '../toml-test/tests')
  ]
  tests_dirs.each do |tests_dir|
    Pathname.glob("#{tests_dir}/{values,valid}/**/*.toml").each do |toml_path|
      toml_path = toml_path.expand_path
      local_path = toml_path.relative_path_from(Pathname.new(File.join(__dir__, "..")))

      it "parses #{local_path}" do
        actual = Tomlrb.load_file(toml_path.to_path)
        json_path = toml_path.sub_ext('.json')
        yaml_path = toml_path.sub_ext('.yaml')
        expected =
          if json_path.exist?
            load_json(json_path)
          elsif yaml_path.exist?
            load_yaml(yaml_path)
          end
        _(actual).must_equal expected
      end
    end

    Pathname.glob("#{tests_dir}/{errors,invalid}/**/*.toml").each do |toml_path|
      toml_path = toml_path.expand_path
      local_path = toml_path.relative_path_from(Pathname.new(File.join(__dir__, "..")))

      it "raises an error on parsing #{local_path}" do
        _{ Tomlrb.load_file(toml_path.to_path) }.must_raise Tomlrb::ParseError, RangeError, ArgumentError
      end
    end
  end
end

def process_json_leaf(node)
  v = node['value']
  case node['type']
  when 'string'
    v
  when 'integer'
    v.to_i
  when 'float'
    case v
    when 'inf', '+inf'
      Float::INFINITY
    when '-inf'
      -Float::INFINITY
    when 'nan'
      Float::NAN
    else
      v.to_f
    end
  when 'bool'
    case v
    when 'true'
      true
    when 'false'
      false
    end
  when 'datetime-local'
    date, time = v.split(/[t ]/i)
    year, month, day = date.split('-')
    hour, min, sec = time.split(':')
    Tomlrb::LocalDateTime.new(year, month, day, hour, min, sec.to_f)
  when 'date', 'date-local'
    Tomlrb::LocalDate.new(*v.split('-'))
  when 'time', 'time-local'
    hour, min, sec = v.split(':')
    Tomlrb::LocalTime.new(hour, min, sec.to_f)
  when 'datetime'
    if v.match?(/\.\d+/)
      date, time = v.split("T")
      year, month, day = date.split("-")
      hour, minute, second_and_zone = time.split(":", 3)
      second, frac_and_zone = second_and_zone.split(".")
      md = frac_and_zone.match(/(?<frac>\d+)(?<zone>.*)/)
      frac = md[:frac]
      zone = md[:zone]

      # Compatibility with Ruby 2.6 and lower
      if zone == 'Z'
        zone = '+00:00'
      end

      Time.new(year, month, day, hour, minute, "#{second}.#{frac}".to_f, zone)
    else
      Time.parse(v)
    end
  end
end

def process_json(node)
  case node
  when Hash
    if node["type"]
      process_json_leaf(node)
    else
      node.each_with_object({}) {|(key, value), table|
        table[key] = process_json(value)
      }
    end
  when Array
    node.map {|entry| process_json(entry)}
  else
    node
  end
end

def load_json(path)
  json = JSON.load(path.open)
  process_json(json)
end

def load_yaml(path)
  data = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(path.read) : YAML.load(path.read)
  local_path = path.parent.basename/path.basename
  if EXPONENTIAL_NOTATIONS.include? local_path.to_path
    data = data.each_with_object({}) {|(key, value), table|
      table[key] = value.to_f
    }
  end
  if UNDERSCORE_NUMBERS.include? local_path.to_path
    data = data.each_with_object({}) {|(key, value), table|
      table[key] = value.to_f
    }
  end
  if RATIONAL_TIME.include? local_path.to_path
    data = data.each_with_object({}) {|(key, value), table|
      sec_frac = value.to_f.to_s.split('.')[1]
      table[key] = Time.new(value.year, value.month, value.day, value.hour, value.min, "#{value.sec}.#{sec_frac}".to_f, value.utc_offset || value.zone)
    }
  end
  if INT_KEY.include? local_path.to_path
    data = data.each_with_object({}) {|(key, value), table|
      table[key.to_s] = value.each_with_object({}) {|(k, v), t| t[k.to_s] = v}
    }
  end

  data
end
