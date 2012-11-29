def stub_ask(*args, &block)
  any_instance_of VMC::CLI do |interactive|
    stub(interactive).ask(*args, &block)
  end
end

def mock_ask(*args, &block)
  any_instance_of VMC::CLI do |interactive|
    mock(interactive).ask(*args, &block)
  end
end

def dont_allow_ask(*args)
  any_instance_of VMC::CLI do |interactive|
    dont_allow(interactive).ask(*args)
  end
end

def mock_with_progress(message)
  any_instance_of VMC::CLI do |interactive|
    mock(interactive).with_progress(message) { |_, block| block.call }
  end
end