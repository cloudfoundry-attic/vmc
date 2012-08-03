# [EventLog]
$vmc_event = nil

class VMC::CLI
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
end

class Mothership::Inputs
  alias_method :vmc_spec_get, :[]

  def [](name, *args)
    val = vmc_spec_get(name, *args)
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
