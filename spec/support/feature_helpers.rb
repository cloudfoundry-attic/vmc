def expect_success
  print_debug_output if status != 0
  expect(status).to eq 0
end

def expect_failure
  print_debug_output if status == 0
  expect(status).to eq 1
end

def vmc(argv)
  stub(VMC::CLI).exit { |code| code }
  capture_output { VMC::CLI.start argv }
end

def bool_flag(flag)
  "#{'no-' unless send(flag)}#{flag.to_s.gsub('_', '-')}"
end

def print_debug_output
  puts stdout.string.strip_progress_dots
  puts stderr.string
end