module OutputHelper
  def capture_output
    fake_stderr = StringIO.new
    fake_stdout = StringIO.new
    real_stdout = $stdout
    real_stderr = $stderr
    $stdout = fake_stdout
    $stderr = fake_stderr

    @stdout = fake_stdout
    @stderr = fake_stderr
    @status = yield
  ensure
    $stdout = real_stdout
    $stderr = real_stderr
  end

  attr_reader :stdout, :stderr, :status
end