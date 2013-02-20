require "expect"
require "pty"

class SpeckerRunner
  attr_reader :output

  def initialize(*args)
    @output = ""

    @stdout, slave = PTY.open
    system("stty raw", :in => slave)
    read, @stdin = IO.pipe

    @pid = spawn(*(args.push(:in => read, :out => slave, :err => slave)))

    yield self
  end

  def expect(matcher, timeout = 30)
    case matcher
    when Hash
      expect_branches(matcher, timeout)
    else
      tracking_expect(matcher, timeout)
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

  private

  def expect_branches(branches, timeout)
    branch_names = /#{branches.keys.collect { |k| Regexp.quote(k) }.join("|")}/
    expected = @stdout.expect(branch_names, timeout)
    return unless expected

    data = expected.first.match(/(#{branch_names})$/)
    matched = data[1]
    branches[matched].call
  end

  def numeric_exit_code(status)
    status.exitstatus
  rescue NoMethodError
    status
  end

  def tracking_expect(pattern, timeout)
    buffer = ''

    case pattern
    when String
      pattern = Regexp.new(Regexp.quote(pattern))
    when Regexp
    else
      raise TypeError, "unsupported pattern class: #{pattern.class}"
    end

    result = nil
    position = 0
    @unused ||= ""

    while true
      if !@unused.empty?
        c = @unused.slice!(0).chr
      elsif !IO.select([@stdout], nil, nil, timeout) || @stdout.eof?
        @unused = buffer
        break
      else
        c = @stdout.getc.chr
      end

      # wear your flip flops
      unless (c == "\e") .. (c == "m")
        if c == "\b"
          if position > 0 && buffer[position - 1] && buffer[position - 1].chr != "\n"
            position -= 1
          end
        else
          if buffer.size > position
            buffer[position] = c
          else
            buffer << c
          end

          position += 1
        end
      end

      if matches = pattern.match(buffer)
        result = [buffer, *matches.to_a[1..-1]]
        break
      end
    end

    @output << buffer

    result
  end
end
