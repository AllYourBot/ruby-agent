require "dotenv/load"
require "reline"

# Register the mcp server
# claude mcp add --transport http headless-browser http://localhost:4567/mcp
# claude --dangerously-skip-permissions

# Before running start the hbt server in a separate terminal:
#   bundle exec hbt start --no-headless --be-human --single-session --session-id=amazon

# Load local development version instead of installed gem
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "ruby_agent"

class MyAgent < RubyAgent::Agent
  on_event :my_handler

  def my_handler(event)
    puts "Event triggered"
    puts "Received event type: #{event['type']}"
    puts "Received event: #{event.dig('message', 'id')}"
  end

  # Or using a block:
  #
  # on_event do |event|
  #  puts "Block event triggered"
  #  puts "Received event in block: #{event.dig("message", "id")}"
  # end
end

DONE = %w[done end eof exit].freeze

def prompt_for_message
  puts "\n(multiline input; type 'end' on its own line when done. or 'exit' to exit)\n\n"

  user_message = Reline.readmultiline("User message: ", true) do |multiline_input|
    last = multiline_input.split.last
    DONE.include?(last)
  end

  return :noop unless user_message

  lines = user_message.split("\n")

  if lines.size > 1 && DONE.include?(lines.last)
    # remove the "done" from the message
    user_message = lines[0..-2].join("\n")
  end

  return :exit if DONE.include?(user_message.downcase)

  user_message
end

begin
  RubyAgent.configure do |config|
    config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil) # Not strictly necessary with claude installed
    config.system_prompt = "You are a helpful AI news  assistant."
    config.model = "claude-sonnet-4-5-20250929"
    config.sandbox_dir = "./news_sandbox"
  end

  agent = MyAgent.new(name: "News-Agent").connect(mcp_servers: { headless_browser: { type: :http,
                                                                                     url: "http://0.0.0.0:4567/mcp" } })

  puts "Welcome to your Claude assistant!"

  loop do
    user_message = prompt_for_message

    case user_message
    when :noop
      next
    when :exit
      break
    end

    puts "Asking Claude..."
    puts agent.ask(user_message)
  end
rescue Interrupt
  puts "\nExiting..."
ensure
  agent&.close
end
