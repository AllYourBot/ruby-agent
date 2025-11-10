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

# Option 1: Use global configuration
RubyAgent.configure do |config|
  config.system_prompt = "You are a helpful assistant."
  config.model = "claude-sonnet-4-5-20250929"
  config.sandbox_dir = "./sandbox"
end

agent = RubyAgent::Agent.new(name: "MyAgent")
agent.connect(verbose: false)

response = agent.ask("What is 1+1?")
puts response

agent.close
```

### Custom Agent with Callbacks

```ruby
require 'ruby_agent'

# Create custom agent class with event callbacks
class MyAgent < RubyAgent::Agent
  # Register callback using method name
  on_event :handle_event

  def handle_event(event)
    case event['type'] 
    # TBD
    end
  end
end

# Initialize and connect
agent = MyAgent.new(
  name: "CustomAgent",
  system_prompt: "You are a helpful coding assistant",
  model: "claude-sonnet-4-5-20250929",
  sandbox_dir: "./my_sandbox"
)

agent.connect(
  timezone: "Eastern Time (US & Canada)",
  skip_permissions: true,
  verbose: true
)

# Send messages
agent.ask("Help me write a Ruby function")
agent.close
```

### Using Block Callbacks

```ruby
require 'ruby_agent'

class MyAgent < RubyAgent::Agent
  # Register callback using block
  on_event do |event|
    # TBD
  end
end

agent = MyAgent.new(name: "BlockAgent")
agent.connect
agent.ask("Tell me a joke")
agent.close
```

### Resuming Sessions

```ruby
require 'ruby_agent'

# First session
agent = RubyAgent::Agent.new(
  name: "MyAgent",
  system_prompt: "You are a helpful assistant"
)

agent.connect(session_key: "my_session_123")
agent.ask("Remember that my name is Alice")
agent.close

# Resume later
agent = RubyAgent::Agent.new(
  name: "MyAgent",
  system_prompt: "You are a helpful assistant"
)

agent.connect(
  session_key: "my_session_123",
  resume_session: true
)
agent.ask("What is my name?")
agent.close
```

### Using MCP Servers

```ruby
require 'ruby_agent'

agent = RubyAgent::Agent.new(
  name: "MCPAgent",
  system_prompt: "You are a helpful assistant with web browsing capabilities"
)

# Connect with MCP server configuration
agent.connect(
  mcp_servers: {
    headless_browser: {
      type: :http,
      url: "http://localhost:4567/mcp"
    }
  }
)

agent.ask("Browse to example.com and summarize the page")
agent.close
```

### Interactive Example

See `examples/example1.rb` for a complete interactive example with multiline input:

```bash
# Start MCP server (if using browser tool)
bundle exec hbt start --no-headless --be-human --single-session

# Run example
ruby examples/example1.rb
```

## Event Callbacks

The callback system allows you to react to events during Claude's response streaming:

### Event Types

- `type: "system"` - System messages
- `type: "assistant"` - Complete assistant messages
- `type: "content_block_delta"` - Streaming text chunks (contains `delta.text`)
- `type: "result"` - Conversation completion
- `type: "error"` - Error messages

### Callback Registration

```ruby
class MyAgent < RubyAgent::Agent
  # Method 1: Using method name
  on_event :my_handler

  def my_handler(event)
    # Process event
  end

  # Method 2: Using block
  on_event do |event|
    # Process event
  end
end
```

Callbacks are executed in registration order and inherited through subclasses

## API

### RubyAgent.new(options)

Creates a new RubyAgent instance.

**Options:**


### Instance Methods

- `connect()` - Connect to Claude
- `ask(text, sender_name: "User", additional: [])` - Send a message to Claude
- `on_event(&block)` - Register a callback for all messages
- `on_error(&block)` - Register a callback for errors

## Error Handling

RubyAgent defines three error types:

- `RubyAgent::AgentError` - Base error class
- `RubyAgent::ConnectionError` - Connection-related errors
- `RubyAgent::ParseError` - System prompt parsing errors

```ruby
begin
  agent.connect
  agent.ask("Hello", sender_name: "User")
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
rake build        # Add locally to run examples
rake install
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
