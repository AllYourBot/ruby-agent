require_relative "ruby_agent/version"
require "shellwords"
require "open3"
require "erb"
require "json"

class RubyAgent
  class AgentError < StandardError; end
  class ConnectionError < AgentError; end
  class ParseError < AgentError; end

  DEBUG = false

  attr_reader :sandbox_dir, :timezone, :skip_permissions, :verbose, :system_prompt, :model, :mcp_servers

  def initialize(
    sandbox_dir: Dir.pwd,
    timezone: "UTC",
    skip_permissions: true,
    verbose: false,
    system_prompt: "You are a helpful assistant",
    model: "claude-sonnet-4-5-20250929",
    mcp_servers: nil,
    session_key: nil,
    **additional_context
  )
    @sandbox_dir = sandbox_dir
    @timezone = timezone
    @skip_permissions = skip_permissions
    @verbose = verbose
    @model = model
    @mcp_servers = mcp_servers
    @session_key = session_key
    @system_prompt = parse_system_prompt(system_prompt, additional_context)
    @on_message_callback = nil
    @on_error_callback = nil
    @dynamic_callbacks = {}
    @custom_message_callbacks = {}
    @stdin = nil
    @stdout = nil
    @stderr = nil
    @wait_thr = nil
    @parsed_lines = []
    @parsed_lines_mutex = Mutex.new
    @pending_ask_after_interrupt = nil
    @pending_interrupt_request_id = nil
    @deferred_exit = false

    return if @session_key

    inject_streaming_response({
                                type: "system",
                                subtype: "prompt",
                                system_prompt: @system_prompt,
                                timestamp: Time.now.utc.iso8601(6),
                                received_at: Time.now.utc.iso8601(6)
                              })
  end

  def create_message_callback(name, &processor)
    @custom_message_callbacks[name.to_s] = {
      processor: processor,
      callback: nil
    }
  end

  def on_message(&block)
    @on_message_callback = block
  end

  alias on_event on_message

  def on_error(&block)
    @on_error_callback = block
  end

  def method_missing(method_name, *args, &block)
    if method_name.to_s.start_with?("on_") && block_given?
      callback_name = method_name.to_s.sub(/^on_/, "")

      if @custom_message_callbacks.key?(callback_name)
        @custom_message_callbacks[callback_name][:callback] = block
      else
        @dynamic_callbacks[callback_name] = block
      end
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.start_with?("on_") || super
  end

  def connect(&block)
    command = build_claude_command

    spawn_process(command, @sandbox_dir) do |stdin, stdout, stderr, wait_thr|
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @wait_thr = wait_thr

      begin
        block.call if block_given?
        receive_streaming_responses
      ensure
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thr = nil
      end
    end
  rescue StandardError => e
    trigger_error(e)
    raise
  end

  def ask(text, sender_name: "User", additional: [])
    formatted_text = if sender_name.downcase == "system"
                       <<~TEXT.strip
                         <system>
                           #{text}
                         </system>
                       TEXT
                     else
                       "#{sender_name}: #{text}"
                     end
    formatted_text += extra_context(additional, sender_name:)

    inject_streaming_response({
                                type: "user",
                                subtype: "new_message",
                                sender_name:,
                                text:,
                                formatted_text:,
                                timestamp: Time.now.utc.iso8601(6)
                              })

    send_message(formatted_text)
  end

  def ask_after_interrupt(text, sender_name: "User", additional: [])
    @pending_ask_after_interrupt = { text:, sender_name:, additional: }
  end

  def send_system_message(text)
    ask(text, sender_name: "system")
  end

  def receive_streaming_responses
    @stdout.each_line do |line|
      next if line.strip.empty?

      begin
        json = JSON.parse(line)

        all_lines = nil
        @parsed_lines_mutex.synchronize do
          @parsed_lines << json
          all_lines = @parsed_lines.dup
        end

        trigger_message(json, all_lines)
        trigger_dynamic_callbacks(json, all_lines)
        trigger_custom_message_callbacks(json, all_lines)
      rescue JSON::ParserError
        warn "Failed to parse line: #{line}" if DEBUG
      end
    end

    puts "→ stdout closed, waiting for process to exit..." if DEBUG
    exit_status = @wait_thr.value
    puts "→ Process exited with status: #{exit_status.success? ? 'success' : 'failure'}" if DEBUG
    unless exit_status.success?
      stderr_output = @stderr.read
      raise ConnectionError, "Claude command failed: #{stderr_output}"
    end

    @parsed_lines
  end

  def inject_streaming_response(event_hash)
    stringified_event = stringify_keys(event_hash)
    all_lines = nil
    @parsed_lines_mutex.synchronize do
      @parsed_lines << stringified_event
      all_lines = @parsed_lines.dup
    end

    trigger_message(stringified_event, all_lines)
    trigger_dynamic_callbacks(stringified_event, all_lines)
    trigger_custom_message_callbacks(stringified_event, all_lines)
  end

  def interrupt
    raise ConnectionError, "Not connected to Claude" unless @stdin
    raise ConnectionError, "Cannot interrupt - stdin is closed" if @stdin.closed?

    @request_counter ||= 0
    @request_counter += 1
    request_id = "req_#{@request_counter}_#{SecureRandom.hex(4)}"

    @pending_interrupt_request_id = request_id if @pending_ask_after_interrupt
    if DEBUG
      puts "→ Sending interrupt with request_id: #{request_id}, pending_ask: #{@pending_ask_after_interrupt ? true : false}"
    end

    control_request = {
      type: "control_request",
      request_id: request_id,
      request: {
        subtype: "interrupt"
      }
    }

    inject_streaming_response({
                                type: "control",
                                subtype: "interrupt",
                                timestamp: Time.now.utc.iso8601(6)
                              })

    @stdin.puts JSON.generate(control_request)
    @stdin.flush
  rescue StandardError => e
    warn "Failed to send interrupt signal: #{e.message}"
    raise
  end

  def exit
    return unless @stdin

    if @pending_interrupt_request_id
      puts "→ Deferring exit - waiting for interrupt response (request_id: #{@pending_interrupt_request_id})" if DEBUG
      @deferred_exit = true
      return
    end

    puts "→ Exiting Claude (closing stdin)" if DEBUG

    begin
      @stdin.close unless @stdin.closed?
      puts "→ stdin closed" if DEBUG
    rescue StandardError => e
      warn "Error closing stdin during exit: #{e.message}"
    end
  end

  private

  def spawn_process(command, sandbox_dir, &)
    Open3.popen3("bash", "-lc", command, chdir: sandbox_dir, &)
  end

  def build_claude_command
    cmd = "claude -p --dangerously-skip-permissions --output-format=stream-json --input-format=stream-json --verbose"
    cmd += " --system-prompt #{Shellwords.escape(@system_prompt)}"
    cmd += " --model #{Shellwords.escape(@model)}"

    if @mcp_servers
      mcp_config = build_mcp_config(@mcp_servers)
      cmd += " --mcp-config #{Shellwords.escape(mcp_config.to_json)}"
    end

    cmd += " --setting-sources \"\""
    cmd += " --resume #{Shellwords.escape(@session_key)}" if @session_key
    cmd
  end

  def build_mcp_config(mcp_servers)
    servers = mcp_servers.transform_keys { |k| k.to_s.gsub("_", "-") }
    { mcpServers: servers }
  end

  def parse_system_prompt(template_content, context_vars)
    if Dir.exist?(@sandbox_dir)
      Dir.chdir(@sandbox_dir) do
        parse_system_prompt_in_context(template_content, context_vars)
      end
    else
      parse_system_prompt_in_context(template_content, context_vars)
    end
  end

  def parse_system_prompt_in_context(template_content, context_vars)
    erb = ERB.new(template_content)
    binding_context = create_binding_context(**context_vars)
    result = erb.result(binding_context)

    raise ParseError, "There was an error parsing the system prompt." if result.include?("<%=") || result.include?("%>")

    result
  end

  def create_binding_context(**vars)
    context = Object.new
    vars.each do |key, value|
      context.instance_variable_set("@#{key}", value)
      context.define_singleton_method(key) { instance_variable_get("@#{key}") }
    end
    context.instance_eval { binding }
  end

  def extra_context(additional = [], sender_name:)
    raise "additional is not an array" unless additional.is_a?(Array)

    return "" if additional.empty?

    <<~CONTEXT

      <extra-context>
      #{additional.join("\n\n")}
      </extra-context>
    CONTEXT
  end

  def send_message(content, session_id = nil)
    raise ConnectionError, "Not connected to Claude" unless @stdin

    message_json = {
      type: "user",
      message: { role: "user", content: content },
      session_id: session_id
    }.compact

    @stdin.puts JSON.generate(message_json)
    @stdin.flush
  rescue StandardError => e
    trigger_error(e)
    raise
  end

  def trigger_message(message, all_messages)
    @on_message_callback&.call(message, all_messages)
  end

  def trigger_dynamic_callbacks(message, all_messages)
    type = message["type"]
    subtype = message["subtype"]

    return unless type

    if type == "control_response"
      puts "→ Received control_response: #{message.inspect}" if DEBUG || @pending_interrupt_request_id
      if @pending_interrupt_request_id
        response = message["response"]
        if response&.dig("subtype") == "success" && response&.dig("request_id") == @pending_interrupt_request_id
          puts "→ Interrupt confirmed, executing queued ask" if DEBUG
          @pending_interrupt_request_id = nil
          if @pending_ask_after_interrupt
            pending = @pending_ask_after_interrupt
            @pending_ask_after_interrupt = nil
            begin
              ask(pending[:text], sender_name: pending[:sender_name], additional: pending[:additional])
            rescue IOError, Errno::EPIPE => e
              warn "Failed to send queued ask after interrupt (stream closed): #{e.message}"
            end
          end

          if @deferred_exit
            puts "→ Executing deferred exit" if DEBUG
            @deferred_exit = false
            exit
          end
        elsif DEBUG
          puts "→ Control response didn't match pending interrupt: #{response.inspect}"
        end
      end
    end

    if subtype
      specific_callback_key = "#{type}_#{subtype}"
      specific_callback = @dynamic_callbacks[specific_callback_key]
      if specific_callback
        puts "→ Triggering callback for: #{specific_callback_key}" if DEBUG
        specific_callback.call(message, all_messages)
      end
    end

    general_callback = @dynamic_callbacks[type]
    if general_callback
      puts "→ Triggering callback for: #{type}" if DEBUG
      general_callback.call(message, all_messages)
    end

    check_nested_content_types(message, all_messages)
  end

  def check_nested_content_types(message, all_messages)
    return unless message["message"].is_a?(Hash)

    content = message.dig("message", "content")
    return unless content.is_a?(Array)

    content.each do |content_item|
      next unless content_item.is_a?(Hash)

      nested_type = content_item["type"]
      next unless nested_type

      callback = @dynamic_callbacks[nested_type]
      if callback
        puts "→ Triggering callback for nested type: #{nested_type}" if DEBUG
        callback.call(message, all_messages)
      end
    end
  end

  def trigger_custom_message_callbacks(message, all_messages)
    @custom_message_callbacks.each_value do |config|
      processor = config[:processor]
      callback = config[:callback]

      next unless processor && callback

      result = processor.call(message, all_messages)
      callback.call(result) if result && !result.to_s.empty?
    end
  end

  def trigger_error(error)
    @on_error_callback&.call(error)
  end

  def stringify_keys(hash)
    hash.transform_keys(&:to_s)
  end
end
