def vmc_ok(argv)
  with_output_to do |out|
    Mothership.new.exit_status 0
    code = VMC::CLI.start(argv + ["--no-script"])
    yield out.string.strip_progress_dots if block_given?
    expect(code).to eq 0
  end
end

def vmc_fail(argv)
  with_output_to do |out|
    code = VMC::CLI.start(argv + ["--no-script"])
    yield out.string.strip_progress_dots if block_given?
    expect(code).to eq 1
  end
end
