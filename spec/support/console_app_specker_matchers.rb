module ConsoleAppSpeckerMatchers
  class InvalidInputError < StandardError; end

  class ExpectOutputMatcher
    attr_reader :timeout

    def initialize(expected_output, timeout = 30)
      @expected_output = expected_output
      @timeout = timeout
    end

    def matches?(runner)
      raise InvalidInputError unless runner.respond_to?(:expect)
      @matched = runner.expect(@expected_output, @timeout)
      @full_output = runner.output
      !!@matched
    end

    def failure_message
      if @expected_output.is_a?(Hash)
        expected_keys = @expected_output.keys.map{|key| "'#{key}'"}.join(', ')
        "expected one of #{expected_keys} to be printed, but it wasn't. full output:\n#@full_output"
      else
        "expected '#{@expected_output}' to be printed, but it wasn't. full output:\n#@full_output"
      end
    end

    def negative_failure_message
      if @expected_output.is_a?(Hash)
        match = @matched
      else
        match = @expected_output
      end

      "expected '#{match}' to not be printed, but it was. full output:\n#@full_output"
    end
  end


  class ExitCodeMatcher
    def initialize(expected_code)
      @expected_code = expected_code
    end

    def matches?(runner)
      raise InvalidInputError unless runner.respond_to?(:exit_code)

      begin
        Timeout.timeout(5) do
          @actual_code = runner.exit_code
        end

        @actual_code == @expected_code
      rescue Timeout::Error
        @timed_out = true
        false
      end
    end

    def failure_message
      if @timed_out
        "expected process to exit with status #@expected_code, but it did not exit within 5 seconds"
      else
        "expected process to exit with status #{@expected_code}, but it exited with status #{@actual_code}"
      end
    end

    def negative_failure_message
      if @timed_out
        "expected process to exit with status #@expected_code, but it did not exit within 5 seconds"
      else
        "expected process to not exit with status #{@expected_code}, but it did"
      end
    end
  end

  def say(expected_output, timeout = 30)
    ExpectOutputMatcher.new(expected_output, timeout)
  end

  def have_exited_with(expected_code)
    ExitCodeMatcher.new(expected_code)
  end

  alias :exit_with :have_exited_with
end
