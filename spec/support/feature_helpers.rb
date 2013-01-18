def vmc_ok(argv)
  Mothership.new.exit_status 0
  capture_output { VMC::CLI.start(argv + ["--no-script"]) }
  output = stdout.string.strip_progress_dots
  puts output if status != 0
  expect(status).to eq 0
  yield output if block_given?
end

def vmc_fail(argv)
  capture_output { VMC::CLI.start(argv + ["--no-script"]) }
  output = stdout.string.strip_progress_dots
  puts output if status == 0
  expect(status).to eq 1
  yield output if block_given?
end

def vmc(argv)
  stub(VMC::CLI).exit { |code| code }
  capture_output { VMC::CLI.start argv }
end

def bool_flag(flag)
  "#{'no-' unless send(flag)}#{flag.to_s.gsub('_', '-')}"
end