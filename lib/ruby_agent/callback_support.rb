module CallbackSupport
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def on_event(method_name = nil, &block)
      @on_event_callbacks ||= []
      @on_event_callbacks << (method_name || block)
    end

    def on_event_callbacks
      callbacks = []
      ancestors.each do |ancestor|
        if ancestor.instance_variable_defined?(:@on_event_callbacks)
          callbacks.concat(ancestor.instance_variable_get(:@on_event_callbacks))
        end
      end
      callbacks
    end

    def method_missing(method_name, *args, &block)
      if method_name.to_s.start_with?("on_event_")
        event_type = method_name.to_s.sub(/^on_event_/, "")
        @specific_event_callbacks ||= {}
        @specific_event_callbacks[event_type] ||= []
        @specific_event_callbacks[event_type] << (args.first || block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_name.to_s.start_with?("on_event_") || super
    end

    def specific_event_callbacks(event_type)
      callbacks = []
      ancestors.each do |ancestor|
        if ancestor.instance_variable_defined?(:@specific_event_callbacks)
          specific_callbacks = ancestor.instance_variable_get(:@specific_event_callbacks)
          callbacks.concat(specific_callbacks[event_type]) if specific_callbacks[event_type]
        end
      end
      callbacks
    end
  end

  def run_callbacks(event_data)
    # Run general on_event callbacks
    self.class.on_event_callbacks.each do |callback|
      if callback.is_a?(Proc)
        instance_exec(event_data, &callback)
      else
        send(callback, event_data)
      end
    end

    # Run event-specific callbacks
    event_type = event_data["type"]
    return unless event_type

    self.class.specific_event_callbacks(event_type).each do |callback|
      if callback.is_a?(Proc)
        instance_exec(event_data, &callback)
      else
        send(callback, event_data)
      end
    end
  end
end
