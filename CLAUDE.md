# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RubyAgent is a Ruby gem framework for building AI agents powered by Claude Code CLI. It provides an event-driven interface to interact with Claude through the Claude Code CLI using stream-json format for bidirectional communication.

## Development Commands

### Testing
```bash
# Run all tests
rake test

# Run specific test
ruby test/ruby_agent_test.rb --name test_simple_agent_query

# Run full CI suite (linting + tests)
rake ci
```

### Linting
```bash
# Check for linting issues
rake ci:lint

# Auto-fix linting issues
rake ci:lint:fix
```

### Security
```bash
# Run security audit
rake ci:scan
```

### Build & Install
```bash
# Build gem locally
rake build

# Install locally built gem
rake install
```

### Running Examples
```bash
# Run example (requires local build/install first)
ruby examples/example1.rb
```

## Architecture

### Core Components

**RubyAgent::Agent** (`lib/ruby_agent/agent.rb`)
- Main agent class that manages Claude Code CLI subprocess communication
- Spawns Claude CLI process using `Open3.popen3` with stream-json I/O format
- Handles bidirectional communication: sends messages via stdin, reads responses via stdout
- Manages connection lifecycle (connect, ask, close)
- Supports session resumption via `session_key` parameter
- Integrates `CallbackSupport` module for event-driven programming model

**RubyAgent::Configuration** (`lib/ruby_agent/configuration.rb`)
- Global configuration object for default settings
- Accessible via `RubyAgent.configuration` or `RubyAgent.configure` block
- Default model: `claude-sonnet-4-5-20250929`
- Default sandbox: `./sandbox`

**CallbackSupport** (`lib/ruby_agent/callback_support.rb`)
- Mixin module providing class-level callback registration
- Supports two callback registration styles:
  1. Method name: `on_event :my_handler`
  2. Block: `on_event do |event| ... end`
- Callbacks are inherited through class ancestry chain
- Events are dispatched during message streaming

### Communication Flow

1. **Connection**: Agent spawns Claude CLI subprocess with specific flags:
   - `--dangerously-skip-permissions`: Skips permission prompts
   - `--output-format=stream-json`: JSON streaming output
   - `--input-format=stream-json`: JSON streaming input
   - `--system-prompt`: Custom system prompt
   - `--model`: Specific Claude model
   - `--mcp-config`: Optional MCP server configuration

2. **Message Sending**: JSON messages sent to stdin with structure:
   ```ruby
   { type: "user", message: { role: "user", content: "..." }, session_id: "..." }
   ```

3. **Response Reading**: Agent reads streaming JSON events from stdout:
   - `type: "system"`: System messages (ignored)
   - `type: "assistant"`: Full assistant messages
   - `type: "content_block_delta"`: Streaming text deltas
   - `type: "result"`: End of response
   - `type: "error"`: Error messages

4. **Callbacks**: Events trigger registered callbacks during streaming

### Callback System Design

The callback system uses Ruby's class-level registration pattern:
- Callbacks registered at class definition time via `on_event`
- Stored in class instance variable `@on_event_callbacks`
- Inherited through ancestor chain for subclass support
- Executed in order during message streaming
- Can be method names (symbols) or blocks (Procs)

### Subprocess Management

The agent uses `Open3.popen3` to spawn Claude CLI:
- Runs in bash login shell (`bash -lc`) to inherit environment
- Changes to sandbox directory before execution
- Optional TTY mode pipes output through `stream.rb` for debugging
- Process health checked via `wait_thr.alive?` before operations

### MCP Server Support

Agents can connect to MCP (Model Context Protocol) servers:
- Configuration passed as JSON via `--mcp-config` flag
- Server keys transformed from snake_case to kebab-case
- Example: `headless_browser` becomes `headless-browser` in config
- MCP servers extend Claude's capabilities with external tools

## Code Style

- Follow Ruby on Rails conventions (Sandi Metz / DHH style)
- Use RuboCop for linting enforcement
- Prefer clear, intention-revealing method names
- Use private methods to hide implementation details
- Follow POODR principles for object design

## Version Management

Version is defined in `lib/ruby_agent/version.rb`. Bump appropriately:
- Patch (0.2.1 → 0.2.2): Bug fixes
- Minor (0.2.1 → 0.3.0): New features
- Major (0.2.1 → 1.0.0): Breaking changes

Publishing to RubyGems happens automatically via GitHub Actions on merge to `main`.

## Testing Notes

- Tests require Claude Code CLI installed locally
- Integration test (`test_simple_agent_query`) spawns real Claude CLI subprocess
- Tests verify callback registration, initialization, ERB template parsing
- Use Minitest framework with minitest-reporters for output

## Requirements

- Ruby >= 3.2.0
- Claude Code CLI installed (see README.md for installation)
- Required gems: dotenv, shellwords (standard library), open3 (standard library), json (standard library), securerandom (standard library)
