module RubyAgent
  class Event
    attr_reader :raw_event

    def initialize(raw_event)
      @raw_event = raw_event
    end
  end
end
