require "thread"

class FakeTTY
  attr_accessor :event

  def initialize
    @input = Queue.new
  end

  def getc
    @input.pop
  end

  def fake(input)
    return if @input.nil?

    input.each_char do |c|
      @input << c
    end
  end

  def close
    @input = nil
  end

  def tty?
    true
  end
end

class EventLog
  attr_accessor :process
  attr_reader :events, :interaction, :inputs

  def initialize(input)
    @input = input

    @queue = Queue.new
    @events = []
    @inputs = {}
  end

  def finish_input
    @input.close
  end

  def next_event
    if @queue.empty?
      if @process.status == false
        raise "Expected more events, but the process has finished."
      elsif @process.status == nil
        begin
          @process.join
        rescue => e
          raise "Expected more events, but process has thrown an exception: #{e}."
        end
      end
    end

    val = @queue.pop
    @events << val
    val
  end

  def pending_events
    events = []

    until @queue.empty?
      events << @queue.pop
    end

    events
  end

  def wait_for_event(type)
    val = next_event

    until val.is_a?(type)
      val = next_event
    end

    val
  end


  def pick_random_option
    options = @interaction.options
    choices = options[:choices]
    chosen = choices[rand(choices.size)]

    if display = options[:display]
      provide("#{display.call(chosen)}\n")
    else
      provide("#{chosen}\n")
    end

    chosen
  end

  def provide(input)
    @input.fake(input)
  end


  def printed(line)
    @queue << Printed.new(line)
  end

  def asking(message, options = {})
    @interaction = Asked.new(message, options)
    @queue << @interaction
  end

  def got_input(name, val)
    @inputs[name] = val
    @queue << GotInput.new(name, val)
  end


  class Printed
    attr_reader :line

    def initialize(line)
      @line = line
    end

    def to_s
      "<Printed '#@line'>"
    end
  end

  class Asked
    attr_reader :message, :options

    def initialize(message, options = {})
      @message = message
      @options = options
    end

    def to_s
      "<Asked '#@message'>"
    end
  end

  class GotInput
    attr_reader :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def to_s
      "<GotInput #@name '#@value'>"
    end
  end
end
