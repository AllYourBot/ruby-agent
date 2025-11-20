require_relative "test_helper"

class TestAgentWithCallbacks < RubyAgent::Agent
  attr_reader :events_received, :assistant_events, :result_events

  def initialize(*args, **kwargs)
    super
    @events_received = []
    @assistant_events = []
    @result_events = []
  end

  on_event :handle_all_events

  on_event_assistant :handle_assistant_event

  on_event_result :handle_result_event

  def handle_all_events(event)
    @events_received << event
  end

  def handle_assistant_event(event)
    @assistant_events << event
  end

  def handle_result_event(event)
    @result_events << event
  end
end

class CallbackSupportTest < Minitest::Test
  def test_class_level_on_event_callback_registration
    callbacks = TestAgentWithCallbacks.on_event_callbacks

    assert_includes callbacks, :handle_all_events
  end

  def test_class_level_specific_event_callback_registration
    assistant_callbacks = TestAgentWithCallbacks.specific_event_callbacks("assistant")
    result_callbacks = TestAgentWithCallbacks.specific_event_callbacks("result")

    assert_includes assistant_callbacks, :handle_assistant_event
    assert_includes result_callbacks, :handle_result_event
  end

  def test_run_callbacks_executes_general_and_specific_callbacks
    agent = TestAgentWithCallbacks.new

    agent.send(:run_callbacks, { "type" => "assistant", "data" => "test" })

    # General callback should receive the event
    assert_equal 1, agent.events_received.length
    assert_equal "assistant", agent.events_received.first["type"]

    # Specific assistant callback should also receive it
    assert_equal 1, agent.assistant_events.length
    assert_equal "assistant", agent.assistant_events.first["type"]

    # Result callback should not receive it
    assert_equal 0, agent.result_events.length
  end

  def test_run_callbacks_with_result_event
    agent = TestAgentWithCallbacks.new

    agent.send(:run_callbacks, { "type" => "result", "status" => "success" })

    # General callback should receive the event
    assert_equal 1, agent.events_received.length
    assert_equal "result", agent.events_received.first["type"]

    # Result callback should receive it
    assert_equal 1, agent.result_events.length
    assert_equal "result", agent.result_events.first["type"]

    # Assistant callback should not receive it
    assert_equal 0, agent.assistant_events.length
  end

  def test_on_event_with_block
    received_events = []

    test_class = Class.new(RubyAgent::Agent) do
      on_event do |event|
        received_events << event
      end

      define_method(:get_received_events) { received_events }
    end

    agent = test_class.new
    agent.send(:run_callbacks, { "type" => "test", "data" => "block test" })

    assert_equal 1, received_events.length
    assert_equal "test", received_events.first["type"]
  end

  def test_on_event_with_dynamic_event_type
    custom_events = []

    test_class = Class.new(RubyAgent::Agent) do
      on_event_custom do |event|
        custom_events << event
      end

      define_method(:get_custom_events) { custom_events }
    end

    agent = test_class.new
    agent.send(:run_callbacks, { "type" => "custom", "message" => "dynamic" })

    assert_equal 1, custom_events.length
    assert_equal "custom", custom_events.first["type"]
  end
end
