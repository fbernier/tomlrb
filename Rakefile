# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "standard/rake"

Minitest::TestTask.create do |t|
  t.test_globs = ["test/test_*.rb"]
  t.warning = true
end

desc "Validate the RBS signatures in sig/"
task :rbs do
  sh "rbs", "-I", "sig", "validate"
end

desc "Run the official toml-test runner (needs Go) for TOML 1.0 and 1.1 against bin/toml-test-decoder"
task :toml_test do
  decoder = File.expand_path("bin/toml-test-decoder", __dir__)
  Dir.chdir("toml-test") do
    %w[1.0 1.1].each do |version|
      sh "go", "run", "./cmd/toml-test", "test", "-toml=#{version}", "-decoder=ruby #{decoder} #{version}"
    end
  end
end

task default: %i[test standard rbs]
