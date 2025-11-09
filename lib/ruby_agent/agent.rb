require_relative "callback_support"

module RubyAgent
  class Agent
    include CallbackSupport

    class ConnectionError < StandardError; end

    attr_reader :name, :sandbox_dir, :timezone, :skip_permissions, :verbose,
                :system_prompt, :mcp_servers, :model, :session_key,
                :context, :conversation_history

    # Configure parameters for the Agent(s) like this or when initializing:
    #
    # RubyAgent.configure do |config|
    #   config.anthropic_api_key = ENV['ANTHROPIC_API_KEY'] # Not strictly necessary with Claude SDK
    #   config.system_prompt = "You are a helpful AI human resources assistant."
    #   config.model = "claude-sonnet-4-5-20250929"
    #   config.sandbox_dir = "./hr_sandbox"
    # end

    # Users can register callbacks in two ways:
    #
    # class MyAgent < RubyAgent::Agent
    #   # Using a method name
    #   on_event :my_handler
    #
    #   def my_handler(event)
    #     text = event.dig("delta", "text")
    #     # Process the streaming text
    #   end
    # end
    #
    # class MyAgent < RubyAgent::Agent
    #   # Using a block
    #   on_event do |event|
    #     text = event.dig("delta", "text")
    #     # Process the streaming text
    #   end
    # end

    def initialize(name: "MyName", system_prompt: nil, model: nil, sandbox_dir: nil)
      @name = name
      @system_prompt = system_prompt || config.system_prompt
      @model = model || config.model
      @sandbox_dir = sandbox_dir || config.sandbox_dir
      @stdin = nil
      @stdout = nil
      @stderr = nil
      @wait_thr = nil
      @parsed_lines = []
      @parsed_lines_mutex = Mutex.new

      return unless @session_key.nil?

      inject_streaming_response({
                                  type: "system",
                                  subtype: "prompt",
                                  system_prompt: @system_prompt,
                                  timestamp: Time.now.iso8601(6),
                                  received_at: Time.now.iso8601(6)
                                })
    end

    def config
      RubyAgent.configuration ||= RubyAgent::Configuration.new
    end

    def connect(
      timezone: "Eastern Time (US & Canada)",
      skip_permissions: true,
      verbose: true,
      mcp_servers: { headless_browser: { type: :http, url: "http://0.0.0.0:4567/mcp" } },
      session_key: nil,
      resume_session: false,
      **additional_context
    )
      @timezone = timezone
      @skip_permissions = skip_permissions
      @verbose = verbose
      @mcp_servers = mcp_servers
      @session_key = session_key
      @resume_session = resume_session
      @context = additional_context
      @conversation_history = []

      ensure_sandbox_exists

      command = build_claude_command

      @stdin, @stdout, @stderr, @wait_thr = spawn_process(command, @sandbox_dir)

      sleep 0.5
      unless @wait_thr.alive?
        error_output = @stderr.read
        raise ConnectionError, "Claude process failed to start. Error: #{error_output}"
      end

      puts "Claude process started successfully (PID: #{@wait_thr.pid})"
      self
    end

    def ask(message)
      return if message.nil? || message.strip.empty?

      send_message(message)
      read_response
    rescue StandardError
      raise
    end

    def close
      return unless @stdin

      @stdin.close unless @stdin.closed?
      @stdout.close unless @stdout.closed?
      @stderr.close unless @stderr.closed?
      @wait_thr&.join
    ensure
      @stdin = nil
      @stdout = nil
      @stderr = nil
      @wait_thr = nil
    end

    def inject_streaming_response(event_hash)
      stringified_event = event_hash.transform_keys(&:to_s)
      all_lines = nil
      @parsed_lines_mutex.synchronize do
        @parsed_lines << stringified_event
        all_lines = @parsed_lines.dup
      end

      # TODO: event handling(?)
      # trigger_event(stringified_event, all_lines)
      # trigger_dynamic_callbacks(stringified_event, all_lines)
      # trigger_custom_event_callbacks(stringified_event, all_lines)
    end

    private

    def ensure_sandbox_exists
      return if File.directory?(@sandbox_dir)

      puts "Creating sandbox directory: #{@sandbox_dir}"
      FileUtils.mkdir_p(@sandbox_dir)
    end

    def build_claude_command
      puts "Building Claude command..."

      cmd = "claude -p --dangerously-skip-permissions --output-format=stream-json --input-format=stream-json"
      cmd += " --verbose" if @verbose
      cmd += " --system-prompt #{Shellwords.escape(@system_prompt)}"
      cmd += " --model #{Shellwords.escape(@model)}"

      if @mcp_servers
        mcp_config_json = build_mcp_config(@mcp_servers).to_json
        cmd += " --mcp-config #{Shellwords.escape(mcp_config_json)}"
      end

      cmd += ' --setting-sources ""'
      cmd += " --resume #{Shellwords.escape(@session_key)}" if @resume_session && @session_key
      cmd
    end

    def build_mcp_config(mcp_servers)
      servers = mcp_servers.transform_keys { |k| k.to_s.gsub("_", "-") }
      { mcpServers: servers }
    end

    def spawn_process(command, sandbox_dir)
      puts "Spawning process with command: #{command}"

      command_to_run = if $stdout.tty? && File.exist?("./stream.rb")
                         "#{command} | tee >(ruby ./stream.rb >/dev/tty)"
                       else
                         command
                       end

      stdin, stdout, stderr, wait_thr = Open3.popen3("bash", "-lc", command_to_run, chdir: sandbox_dir)
      [stdin, stdout, stderr, wait_thr]
    end

    def send_message(content, session_id = nil)
      raise ConnectionError, "Not connected to Claude" unless @stdin

      unless @wait_thr&.alive?
        error_output = @stderr&.read || "Unknown error"
        raise ConnectionError, "Claude process has died. Error: #{error_output}"
      end

      message_json = {
        type: "user",
        message: { role: "user", content: content },
        session_id: session_id
      }.compact

      @stdin.puts JSON.generate(message_json)
      @stdin.flush
    rescue StandardError
      raise
    end

    def read_response
      response_text = ""

      loop do
        unless @wait_thr.alive?
          error_output = @stderr.read
          raise ConnectionError, "Claude process died while reading response. Error: #{error_output}"
        end

        ready = IO.select([@stdout, @stderr], nil, nil, 0.1)

        next unless ready

        if ready[0].include?(@stderr)
          error_line = @stderr.gets
          warn error_line if error_line
        end

        next unless ready[0].include?(@stdout)

        line = @stdout.gets
        break unless line

        line = line.strip
        next if line.empty?

        begin
          message = JSON.parse(line)

          case message["type"]
          when "system"
            next
          when "assistant"
            if message.dig("message", "content")
              content = message["message"]["content"]
              if content.is_a?(Array)
                content.each do |block|
                  if block["type"] == "text" && block["text"]
                    text = block["text"]
                    response_text += text
                  end
                end
              elsif content.is_a?(String)
                response_text += content
              end
            end
          when "content_block_delta"
            if message.dig("delta", "text")
              text = message["delta"]["text"]
              response_text += text
              print text
            end
          when "result"
            break
          when "error"
            puts "[ERROR] #{message['message']}"
            break
          end
          run_callbacks(message)
        rescue JSON::ParserError
          warn "Failed to parse JSON: #{line[0..100]}"
          next
        end
      end

      puts
      response_text
    end
  end
end
