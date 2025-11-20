module RubyAgent
  class Configuration
    attr_accessor :anthropic_api_key, :system_prompt, :model, :sandbox_dir

    def initialize
      @anthropic_api_key = nil # Not necessarily required with Claude SDK
      @system_prompt = "You are a helpful AI assistant."
      @model = "claude-sonnet-4-5-20250929"
      @sandbox_dir = "./sandbox"
    end
  end
end
