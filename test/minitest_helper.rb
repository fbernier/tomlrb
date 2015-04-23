$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'tomlrb'
require 'pry'

require 'minitest/spec'
require 'minitest/autorun'
require "minitest/reporters"
Minitest::Reporters.use!
