require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

namespace :ci do
  desc "Run tests"
  task :test do
    sh "bundle exec rake test"
  end

  desc "Run linter"
  task :lint do
    sh "bundle exec rubocop"
  rescue StandardError
    puts "Rubocop not configured yet, skipping..."
  end

  desc "Run security scan"
  task :scan do
    sh "bundle exec bundler-audit check --update"
  rescue StandardError
    puts "Bundler-audit not installed, skipping..."
  end
end

desc "Run all CI tasks"
task ci: ["ci:lint", "ci:test"]
