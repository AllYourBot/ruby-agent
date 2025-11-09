require "minitest/autorun"
require_relative "../lib/ruby_agent"

begin
  require "minitest/reporters"
  Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
rescue LoadError # rubocop:disable Lint/SuppressedException
end
