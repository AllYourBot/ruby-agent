# Before running:
# start the hbt server:
#   bundle exec hbt start --no-headless --be-human --single-session --session-id=amazon
# claude mcp add --transport http headless-browser http://localhost:4567/mcp
# claude --dangerously-skip-permissions

# Load local development version instead of installed gem
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "ruby_agent"

class MyAgent < RubyAgent::Agent
  on_event :my_handler

  def my_handler(event)
    puts "Event triggered"
    puts "Received event: #{event.dig('message', 'id')}"
  end

  # Or using a block:
  #
  # on_event do |event|
  #  puts "Block event triggered"
  #  puts "Received event in block: #{event.dig("message", "id")}"
  # end
end

RubyAgent.configure do |config|
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil) # Not strictly necessary with claude installed
  config.system_prompt = "You are a helpful AI news  assistant."
  config.model = "claude-sonnet-4-5-20250929"
  config.sandbox_dir = "./news_sandbox"
end

agent = MyAgent.new(name: "News-Agent").connect

puts agent.ask("Go to google.com and search for Boston")

agent.close
