def vmc_ok(argv)
  expect(VMC::CLI.start(argv + ["--no-script"])).to eq 0
end

def vmc_fail(argv)
  expect(VMC::CLI.start(argv + ["--no-script"])).to_not eq 0
end