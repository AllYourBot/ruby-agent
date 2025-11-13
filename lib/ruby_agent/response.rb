module RubyAgent
  class Response
    attr_reader :events, :text

    def initialize(text: "", events: [])
      @text = text
      @events = events
    end

    def final
      @text
    end

    def to_s
      @text
    end

    def add_event(event)
      @events << event
      self
    end

    def append_text(content)
      @text += content
      self
    end
  end
end