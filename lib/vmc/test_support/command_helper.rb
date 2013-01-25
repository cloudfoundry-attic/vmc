module VMC::TestSupport::CommandHelper
  def vmc(argv)
    stub(VMC::CLI).exit { |code| code }
    capture_output { VMC::CLI.start argv }
  end

  def expect_success
    print_debug_output if status != 0
    expect(status).to eq 0
  end

  def expect_failure
    print_debug_output if status == 0
    expect(status).to eq 1
  end

  def bool_flag(flag)
    "#{'no-' unless send(flag)}#{flag.to_s.gsub('_', '-')}"
  end

  def print_debug_output
    puts stdout.string.strip_progress_dots
    puts stderr.string
  end

  attr_reader :stdout, :stderr, :status

  def capture_output
    real_stdout = $stdout
    real_stderr = $stderr
    $stdout = @stdout = StringIO.new
    $stderr = @stderr = StringIO.new
    @status = yield
  ensure
    $stdout = real_stdout
    $stderr = real_stderr
  end
end
