def stub_ask(*args, &block)
  a_stub = nil
  any_instance_of VMC::CLI do |interactive|
    a_stub = stub(interactive).ask(*args, &block)
  end
  a_stub
end

def mock_ask(*args, &block)
  a_mock = nil
  any_instance_of VMC::CLI do |interactive|
    a_mock = mock(interactive).ask(*args, &block)
  end
  a_mock
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
