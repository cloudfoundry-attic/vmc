# [EventLog]
$vmc_event = nil

class VMC::CLI
  def run(name)
    if input[:help]
      invoke :help, :command => cmd.name.to_s
    else
      precondition
      super
    end
  end

  class ProgressEventReporter
    def initialize(message, skipper)
      @message = message
      @skipper = skipper
      @skipped = false
    end

    def skip(&blk)
      @skipped = true
      $vmc_event.skipped(@message)
      @skipper.skip(&blk)
    end

    def fail(&blk)
      @skipped = true
      $vmc_event.failed_to(@message)
      @skipper.fail(&blk)
    end

    def give_up(&blk)
      @skipped = true
      $vmc_event.gave_up(@message)
      @skipper.give_up(&blk)
    end

    def skipped?
      @skipped
    end
  end

  def ask(*args)
    $vmc_event.asking(*args) if $vmc_event
    super
  end

  def line(*args)
    $vmc_event.printed(*args) if $vmc_event
    super
  end

  def force?
    false
  end

  def with_progress(msg, &blk)
    super(msg) do |s|
      reporter = ProgressEventReporter.new(msg, s)

      res = blk.call(reporter)

      $vmc_event.did(msg) unless reporter.skipped?

      res
    end
  rescue
    $vmc_event.failed_to(msg)
    raise
  end
end

class Mothership::Inputs
  alias_method :vmc_spec_get, :get

  def get(name, context, *args)
    val = vmc_spec_get(name, context, *args)
    $vmc_event.got_input(name, val) if $vmc_event
    val
  end
end

module Interactive
  def set_input_state(input)
  end

  def restore_input_state(input, before)
  end
end
