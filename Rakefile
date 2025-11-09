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

  namespace :lint do
    desc "Run linter"
    task :default do
      sh "bundle exec rubocop"
    end

    desc "Auto-fix linting issues"
    task :fix do
      sh "bundle exec rubocop -a"
    end
  end

  desc "Run security scan"
  task :scan do
    sh "bundle exec bundler-audit check --update"
  end

  # alias ci:lint to ci:lint:default
  task lint: "lint:default"
end

desc "Run all CI tasks"
task ci: ["ci:lint", "ci:test"]
