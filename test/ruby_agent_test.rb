require_relative "test_helper"

class RubyAgentTest < Minitest::Test
  def test_initialization_with_defaults
    agent = RubyAgent::Agent.new

    assert_equal "MyName", agent.name
    assert_equal "You are a helpful AI assistant.", agent.system_prompt
    assert_equal "claude-sonnet-4-5-20250929", agent.model
    assert_equal "./sandbox", agent.sandbox_dir
  end

  def test_initialization_with_custom_options
    agent = RubyAgent::Agent.new(
      name: "TestAgent",
      sandbox_dir: "/tmp",
      system_prompt: "Custom prompt",
      model: "claude-opus-4"
    )

    assert_equal "TestAgent", agent.name
    assert_equal "/tmp", agent.sandbox_dir
    assert_equal "Custom prompt", agent.system_prompt
    assert_equal "claude-opus-4", agent.model
  end

  def test_configuration_integration
    RubyAgent.configure do |config|
      config.system_prompt = "Configured prompt"
      config.model = "claude-opus-4"
      config.sandbox_dir = "/tmp/test"
    end

    agent = RubyAgent::Agent.new

    assert_equal "Configured prompt", agent.system_prompt
    assert_equal "claude-opus-4", agent.model
    assert_equal "/tmp/test", agent.sandbox_dir
  ensure
    # Reset configuration
    RubyAgent.configuration = nil
  end

  def test_configuration_can_be_overridden_at_initialization
    RubyAgent.configure do |config|
      config.system_prompt = "Configured prompt"
      config.model = "claude-opus-4"
    end

    agent = RubyAgent::Agent.new(
      system_prompt: "Override prompt",
      model: "claude-sonnet-4-5-20250929"
    )

    assert_equal "Override prompt", agent.system_prompt
    assert_equal "claude-sonnet-4-5-20250929", agent.model
  ensure
    # Reset configuration
    RubyAgent.configuration = nil
  end

  def test_ask_raises_when_not_connected
    agent = RubyAgent::Agent.new

    error = assert_raises(RubyAgent::Agent::ConnectionError) do
      agent.ask("Hello")
    end

    assert_match(/Not connected/, error.message)
  end

  def test_ask_ignores_nil_or_empty_messages
    agent = RubyAgent::Agent.new

    # These should return early without raising errors
    assert_nil agent.ask(nil)
    assert_nil agent.ask("")
    assert_nil agent.ask("   ")
  end

  def test_close_is_safe_when_not_connected
    agent = RubyAgent::Agent.new

    # Should not raise an error
    assert_nil agent.close
  end
end
