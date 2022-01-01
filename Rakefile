# To avoid stack level too deep error on loading
# toml-spec-tests/values/qa-table-inline-nested-1000.yaml
ENV["RUBY_THREAD_VM_STACK_SIZE"] = "1100000"

require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end
task test: :compile

task default: [:test]

task :compile do
  sh 'racc lib/tomlrb/parser.y -o lib/tomlrb/generated_parser.rb'
end
