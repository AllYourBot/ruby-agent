require_relative "test_helper"

class ResponseTest < Minitest::Test
  def test_response_initialization_with_defaults
    response = RubyAgent::Response.new

    assert_equal "", response.text
    assert_equal [], response.events
  end

  def test_response_initialization_with_text_and_events
    events = [{ "type" => "test" }]
    response = RubyAgent::Response.new(text: "Hello", events: events)

    assert_equal "Hello", response.text
    assert_equal events, response.events
  end

  def test_append_text_concatenates_content
    response = RubyAgent::Response.new

    response.append_text("Hello")
    assert_equal "Hello", response.text

    response.append_text(" World")
    assert_equal "Hello World", response.text
  end

  def test_append_text_returns_self_for_chaining
    response = RubyAgent::Response.new

    result = response.append_text("test")
    assert_same response, result
  end

  def test_add_event_adds_to_events_array
    response = RubyAgent::Response.new

    event1 = { "type" => "assistant", "data" => "test" }
    event2 = { "type" => "result", "status" => "success" }

    response.add_event(event1)
    response.add_event(event2)

    assert_equal 2, response.events.length
    assert_equal event1, response.events[0]
    assert_equal event2, response.events[1]
  end

  def test_add_event_returns_self_for_chaining
    response = RubyAgent::Response.new

    result = response.add_event({ "type" => "test" })
    assert_same response, result
  end

  def test_final_text_returns_accumulated_text
    response = RubyAgent::Response.new

    response.append_text("Hello")
    response.append_text(" ")
    response.append_text("World")

    assert_equal "Hello World", response.final_text
  end

  def test_chaining_methods
    response = RubyAgent::Response.new

    response
      .add_event({ "type" => "start" })
      .append_text("Hello")
      .append_text(" World")
      .add_event({ "type" => "end" })

    assert_equal "Hello World", response.text
    assert_equal 2, response.events.length
  end
end
