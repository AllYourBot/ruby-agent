# RubyAgent

A Ruby framework for building AI agents powered by Claude Code. This gem provides a simple, event-driven interface to interact with Claude through the Claude Code CLI.

## Prerequisites

Before using RubyAgent, you need to install Claude Code CLI:

### macOS
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

### Windows
```powershell
irm https://claude.ai/install.ps1 | iex
```

For more information, visit the [Claude Code documentation](https://www.claude.com/product/claude-code).

## Installation

```bash
gem install ruby_agent
```

Or add to your Gemfile:

```ruby
gem 'ruby_agent'
```

## Usage

### Basic Example

```ruby
require 'ruby_agent'

agent = RubyAgent.new
agent.on_result { |e, _| agent.exit if e["subtype"] == "success" }
agent.connect { agent.ask("What is 2+2?") }
```

That's it! Three lines to create an agent, ask Claude a question, and exit when done.

### Advanced Example with Callbacks

```ruby
require 'ruby_agent'

agent = RubyAgent.new(
  sandbox_dir: Dir.pwd,
  system_prompt: "You are a helpful coding assistant",
  model: "claude-sonnet-4-5-20250929",
  verbose: true
)

agent.create_message_callback :assistant_text do |event, all_events|
  if event["type"] == "assistant" && event.dig("message", "content", 0, "type") == "text"
    event.dig("message", "content", 0, "text")
  end
end

agent.on_system_init do |event, _|
  puts "Session started: #{event['session_id']}"
end

agent.on_assistant_text do |text|
  puts "Claude says: #{text}"
end

agent.on_result do |event, all_events|
  if event["subtype"] == "success"
    puts "Task completed successfully!"
    agent.exit
  elsif event["subtype"] == "error_occurred"
    puts "Error: #{event['result']}"
    agent.exit
  end
end

agent.on_error do |error|
  puts "Error occurred: #{error.message}"
end

agent.connect do
  agent.ask("Write a simple Hello World function in Ruby", sender_name: "User")
end
```

### Resuming Sessions

```ruby
agent = RubyAgent.new(
  session_key: "existing_session_123",
  system_prompt: "You are a helpful assistant"
)

agent.connect do
  agent.ask("Continue from where we left off", sender_name: "User")
end
```

### Using ERB in System Prompts

```ruby
agent = RubyAgent.new(
  system_prompt: "You are <%= role %> working on <%= project_name %>",
  role: "a senior developer",
  project_name: "RubyAgent"
)
```

## Event Callbacks

RubyAgent supports dynamic event callbacks using `method_missing`. You can create callbacks for any event type:

- `on_message` (alias: `on_event`) - Triggered for every message
- `on_assistant` - Triggered when Claude responds
- `on_system_init` - Triggered when a session starts
- `on_result` - Triggered when a task completes
- `on_error` - Triggered when an error occurs
- `on_tool_use` - Triggered when Claude uses a tool
- `on_tool_result` - Triggered when a tool returns results

You can also create custom callbacks with specific subtypes like `on_system_init`, `on_error_timeout`, etc.

## Custom Message Callbacks

Create custom message processors that filter and transform events:

```ruby
agent.create_message_callback :important_messages do |message, all_messages|
  if message["type"] == "assistant"
    message.dig("message", "content", 0, "text")
  end
end

agent.on_important_messages do |text|
  puts "Important: #{text}"
end
```

## API

### RubyAgent.new(options)

Creates a new RubyAgent instance.

**Options:**
- `sandbox_dir` (String) - Working directory for the agent (default: `Dir.pwd`)
- `timezone` (String) - Timezone for the agent (default: `"UTC"`)
- `skip_permissions` (Boolean) - Skip permission prompts (default: `true`)
- `verbose` (Boolean) - Enable verbose output (default: `false`)
- `system_prompt` (String) - System prompt for Claude (default: `"You are a helpful assistant"`)
- `model` (String) - Claude model to use (default: `"claude-sonnet-4-5-20250929"`)
- `mcp_servers` (Hash) - MCP server configuration (default: `nil`)
- `session_key` (String) - Resume an existing session (default: `nil`)
- Additional keyword arguments are passed to the ERB template in `system_prompt`

### Instance Methods

- `connect(&block)` - Connect to Claude and execute the block
- `ask(text, sender_name: "User", additional: [])` - Send a message to Claude
- `send_system_message(text)` - Send a system message
- `interrupt` - Interrupt Claude's current operation
- `exit` - Close the connection to Claude
- `on_message(&block)` - Register a callback for all messages
- `on_error(&block)` - Register a callback for errors
- Dynamic `on_*` methods for specific event types

## Error Handling

RubyAgent defines three error types:

- `RubyAgent::AgentError` - Base error class
- `RubyAgent::ConnectionError` - Connection-related errors
- `RubyAgent::ParseError` - System prompt parsing errors

```ruby
begin
  agent.connect do
    agent.ask("Hello", sender_name: "User")
  end
rescue RubyAgent::ConnectionError => e
  puts "Connection failed: #{e.message}"
rescue RubyAgent::AgentError => e
  puts "Agent error: #{e.message}"
end
```

## Development

### Contributing

1. Fork the repository: https://github.com/AllYourBot/ruby-agent
2. Create a feature branch: `git checkout -b my-new-feature`
3. Make your changes
4. Run the CI suite locally to ensure everything passes:

```bash
# Run all CI tasks (linting + tests)
rake ci

# Or run tasks individually:
rake ci:test      # Run test suite
rake ci:lint      # Run RuboCop linter
rake ci:lint:fix  # Auto-fix linting issues
rake ci:scan      # Run security audit
```

5. Commit your changes: `git commit -am 'Add some feature'`
6. Push to your fork: `git push origin my-new-feature`
7. Create a Pull Request against the `main` branch

### Running Tests Locally

The test suite includes an integration test that runs Claude Code CLI locally:

```bash
# Run all tests
rake test

# Run a specific test
ruby test/ruby_agent_test.rb --name test_simple_agent_query
```

**Note**: Tests require Claude Code CLI to be installed on your machine (see Prerequisites section).

### Linting

We use RuboCop for code linting:

```bash
# Check for linting issues
rake ci:lint

# Auto-fix linting issues
rake ci:lint:fix
```

### Publishing

Publishing to RubyGems happens automatically via GitHub Actions when code is merged to `main`. The version number is read from `lib/ruby_agent/version.rb`.

**Before merging a PR**, make sure to bump the version number appropriately:
- Patch version (0.2.1 → 0.2.2) for bug fixes
- Minor version (0.2.1 → 0.3.0) for new features
- Major version (0.2.1 → 1.0.0) for breaking changes

## License

MIT
