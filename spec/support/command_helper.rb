module CommandHelper
  def vmc(argv)
    Mothership.new.exit_status 0
    stub(VMC::CLI).exit { |code| code }
    capture_output { VMC::CLI.start(argv + ["--debug"]) }
  end

  def expect_status_and_output(status = 0, out = "", err = "")
    expect([
      status,
      stdout.string.strip_progress_dots,
      stderr.string.strip_progress_dots
    ]).to eq([status, out, err])
  end

  def bool_flag(flag)
    "#{'no-' unless send(flag)}#{flag.to_s.gsub('_', '-')}"
  end

  attr_reader :stdout, :stderr, :status

  def capture_output
    $real_stdout = $stdout
    $real_stderr = $stderr
    $stdout = @stdout = StringIO.new
    $stderr = @stderr = StringIO.new
    @status = yield
  ensure
    $stdout = $real_stdout
    $stderr = $real_stderr
  end
end
