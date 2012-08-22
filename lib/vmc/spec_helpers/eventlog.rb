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
      if val.important?
        raise "Tried to skip important event while waiting for a #{type}: #{val}"
      end

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

  def raised(exception)
    @queue << Raised.new(exception)
  end

  def did(message)
    @queue << Did.new(message)
  end

  def skipped(message)
    @queue << Skipped.new(message)
  end

  def failed_to(message)
    @queue << FailedTo.new(message)
  end

  def gave_up(message)
    @queue << GaveUp.new(message)
  end


  class Event
    def important?
      true
    end
  end

  class Printed < Event
    attr_reader :line

    def initialize(line)
      @line = line
    end

    def to_s
      "<Printed '#@line'>"
    end
  end

  class Asked < Event
    attr_reader :message, :options

    def initialize(message, options = {})
      @message = message
      @options = options
    end

    def to_s
      "<Asked '#@message'>"
    end
  end

  class GotInput < Event
    attr_reader :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def to_s
      "<GotInput #@name '#@value'>"
    end

    def important?
      false
    end
  end

  class Raised < Event
    attr_reader :exception

    def initialize(exception)
      @exception = exception
    end

    def to_s
      "<Raised #{@exception.class} '#@exception'>"
    end
  end

  class Progress < Event
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def ==(other)
      other.is_a?(self.class) &&
        @message == other.message
    end
  end

  class Did < Progress
    def to_s
      "<Did '#@message'>"
    end

    def report
      "do '#@message'"
    end

    def report_past
      "did '#@message'"
    end
  end

  class Skipped < Progress
    def to_s
      "<Skipped '#@message'>"
    end

    def report
      "skip '#@message'"
    end

    def report_past
      "skipped '#@message'"
    end
  end

  class FailedTo < Progress
    def to_s
      "<FailedTo '#@message'>"
    end

    def report
      "fail to '#@message'"
    end

    def report_past
      "failed to '#@message'"
    end
  end

  class GaveUp < Progress
    def to_s
      "<GaveUp '#@message'>"
    end

    def report
      "give up on '#@message'"
    end

    def report_past
      "gave up on '#@message'"
    end
  end
end
