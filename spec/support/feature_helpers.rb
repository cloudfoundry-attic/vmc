def vmc_ok(argv)
  Mothership.new.exit_status 0
  capture_output { VMC::CLI.start(argv + ["--no-script"]) }
  expect(status).to eq 0
  yield stdout.string.strip_progress_dots if block_given?
end

def vmc_fail(argv)
  capture_output { VMC::CLI.start(argv + ["--no-script"]) }
  expect(status).to eq 1
  yield stdout.string.strip_progress_dots if block_given?
end
