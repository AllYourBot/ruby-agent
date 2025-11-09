require_relative 'test_helper'

class RubyAgentTest < Minitest::Test
  def test_simple_agent_query
    agent = RubyAgent.new(
      system_prompt: "You are a helpful assistant. Be very concise.",
      model: "claude-sonnet-4-5-20250929",
      verbose: false
    )

    assistant_responses = []
    result_received = false

    agent.on_assistant do |event, _all_events|
      if event.dig("message", "content", 0, "type") == "text"
        text = event.dig("message", "content", 0, "text")
        assistant_responses << text
      end
    end

    agent.on_result do |event, _all_events|
      result_received = true
      agent.exit if event["subtype"] == "success"
    end

    agent.connect do
      agent.ask("What is 1+1? Just give me the number.", sender_name: "User")
    end

    assert result_received, "Expected to receive a result event"
    assert assistant_responses.any? { |r| r.include?("2") }, "Expected assistant to answer '2'"
  end

  def test_initialization_with_defaults
    agent = RubyAgent.new

    assert_equal Dir.pwd, agent.sandbox_dir
    assert_equal "UTC", agent.timezone
    assert agent.skip_permissions
    refute agent.verbose
    assert_equal "You are a helpful assistant", agent.system_prompt
    assert_equal "claude-sonnet-4-5-20250929", agent.model
  end

  def test_initialization_with_custom_options
    agent = RubyAgent.new(
      sandbox_dir: "/tmp",
      timezone: "America/New_York",
      skip_permissions: false,
      verbose: true,
      system_prompt: "Custom prompt",
      model: "claude-opus-4"
    )

    assert_equal "/tmp", agent.sandbox_dir
    assert_equal "America/New_York", agent.timezone
    refute agent.skip_permissions
    assert agent.verbose
    assert_equal "Custom prompt", agent.system_prompt
    assert_equal "claude-opus-4", agent.model
  end

  def test_erb_system_prompt_parsing
    agent = RubyAgent.new(
      system_prompt: "Hello <%= name %>, you are <%= role %>.",
      name: "Claude",
      role: "assistant"
    )

    assert_equal "Hello Claude, you are assistant.", agent.system_prompt
  end

  def test_erb_system_prompt_raises_on_undefined_variable
    assert_raises(NameError) do
      RubyAgent.new(
        system_prompt: "Hello <%= undefined_var %>"
      )
    end
  end

  def test_on_message_callback_registration
    agent = RubyAgent.new

    agent.on_message do |message, all_messages|
    end

    assert agent.instance_variable_get(:@on_message_callback), "Expected on_message callback to be registered"
  end

  def test_dynamic_callbacks_via_method_missing
    agent = RubyAgent.new

    agent.on_custom_event do |message, all_messages|
    end

    dynamic_callbacks = agent.instance_variable_get(:@dynamic_callbacks)
    assert dynamic_callbacks.key?("custom_event"), "Expected custom_event callback to be registered"
  end

  def test_create_message_callback
    agent = RubyAgent.new

    agent.create_message_callback :test_callback do |message, all_messages|
      "processed"
    end

    custom_callbacks = agent.instance_variable_get(:@custom_message_callbacks)
    assert custom_callbacks.key?("test_callback"), "Expected test_callback to be registered"
  end
end
