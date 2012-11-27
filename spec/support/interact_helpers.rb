def stub_ask(question=anything, options=anything, &block)
  any_instance_of VMC::CLI do |interactive|
    stub(interactive).ask(question, options, &block)
  end
end

def mock_ask(question=anything, options=anything, &block)
  any_instance_of VMC::CLI do |interactive|
    mock(interactive).ask(question, options, &block)
  end
end

def dont_allow_ask(question=anything, options=anything, &block)
  any_instance_of VMC::CLI do |interactive|
    dont_allow(interactive).ask(question, options, &block)
  end
end