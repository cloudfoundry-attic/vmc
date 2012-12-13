def vmc_ok(argv)
  with_output_to do |out|
    code = VMC::CLI.start(argv + ["--no-script"])
    yield strip_progress_dots(out.string) if block_given?
    expect(code).to eq 0
  end
end

def vmc_fail(argv)
  with_output_to do |out|
    code = VMC::CLI.start(argv + ["--no-script"])
    yield strip_progress_dots(out.string) if block_given?
    expect(code).to eq 1
  end
end

def strip_progress_dots(str)
  str.gsub(/\.  \x08([\x08\. ]+)/, "... ")
end
