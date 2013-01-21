def expect_success
  puts stdout.string.strip_progress_dots if status != 0
  expect(status).to eq 0
end

def expect_failure
  puts stdout.string.strip_progress_dots if status == 0
  expect(status).to eq 1
end

def vmc(argv)
  stub(VMC::CLI).exit { |code| code }
  capture_output { VMC::CLI.start argv }
end

def bool_flag(flag)
  "#{'no-' unless send(flag)}#{flag.to_s.gsub('_', '-')}"
end