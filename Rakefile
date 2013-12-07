require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rspec/core/rake_task'
require 'coveralls/rake/task'
require 'English'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
end

RSpec::Core::RakeTask.new(:spec)

Coveralls::RakeTask.new

task :test_all do
  failures = []

  fork do
    Rake::Task[:test].invoke
  end
  Process.wait
  failures << 'TestUnit' unless $CHILD_STATUS.exitstatus == 0

  fork do
    Rake::Task[:spec].invoke
  end
  Process.wait
  failures << 'RSpec' unless $CHILD_STATUS.exitstatus == 0

  Rake::Task['coveralls:push'].invoke if ENV['CI']

  if failures.any?
    raise RuntimeError, "\n\nTest failures occured in test suite(s): #{failures.join(', ')}\n", []
  end
end

task :default => :test_all
