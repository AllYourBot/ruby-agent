require "dotenv/load"
require "shellwords"
require "open3"
require "json"
require "fileutils"
require "securerandom"

require_relative "ruby_agent/version"
require_relative "ruby_agent/configuration"
require_relative "ruby_agent/agent"
require_relative "ruby_agent/callback_support"

module RubyAgent
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
end
