require "pty"

class SpeckerRunner
  def initialize(*args)
    @stdout, slave = PTY.open
    system("stty raw", :in => slave)
    read, @stdin = IO.pipe

    @pid = spawn(*(args.push(:in => read, :out => slave, :err => slave)))

    @expector = TrackingExpector.new(@stdout, ENV["DEBUG_BACON"])

    yield self
  end

  def expect(matcher, timeout = 30)
    case matcher
    when Hash
      expect_branches(matcher, timeout)
    else
      @expector.expect(matcher, timeout)
    end
  end

  def send_keys(text_to_send)
    @stdin.puts(text_to_send)
  end

  def exit_code
    return @status if @status

    status = nil
    Timeout.timeout(5) do
      _, status = Process.waitpid2(@pid)
    end

    @status = numeric_exit_code(status)
  end

  alias_method :wait_for_exit, :exit_code

  def exited?
    !running?
  end

  def running?
    !!Process.getpgid(@pid)
  end

  def output
    @expector.output
  end

  def debug
    @expector.debug
  end

  def debug=(x)
    @expector.debug = x
  end

  private

  def expect_branches(branches, timeout)
    branch_names = /#{branches.keys.collect { |k| Regexp.quote(k) }.join("|")}/
    expected = @expector.expect(branch_names, timeout)
    return unless expected

    data = expected.first.match(/(#{branch_names})$/)
    matched = data[1]
    branches[matched].call
    matched
  end

  def numeric_exit_code(status)
    status.exitstatus
  rescue NoMethodError
    status
  end
end
