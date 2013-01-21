module OutputHelper
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

  attr_reader :stdout, :stderr, :status
end