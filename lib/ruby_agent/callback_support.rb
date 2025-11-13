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
  end

  def run_callbacks(event_data)
    self.class.on_event_callbacks.each do |callback|
      if callback.is_a?(Proc)
        instance_exec(event_data, &callback)
      else
        send(callback, event_data)
      end
    end
  end
end
