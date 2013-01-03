def vmc_ok(argv)
  code = 0
  output = ""
  with_output_to do |out|
    code = VMC::CLI.start(argv + ["--no-script"])
    yield out.string.strip_progress_dots if block_given?
    output = "OUTPUT:\n#{out}\n\n"
    # expect(code).to eq 0
  end
  if code != 0
    if File.exist?("/home/travis/builds/cloudfoundry/vmc/spec/tmp/.vmc/crash")
      $stderr.puts "Found the crash file"
      crashes = File.readlines("/home/travis/builds/cloudfoundry/vmc/spec/tmp/.vmc/crash")
      output = "#{output} CRASHLOGS:\n#{crashes}\n"
    end
    $stderr.puts output
  end
end

def vmc_fail(argv)
  with_output_to do |out|
    code = VMC::CLI.start(argv + ["--no-script"])
    yield out.string.strip_progress_dots if block_given?
    expect(code).to eq 1
  end
end
