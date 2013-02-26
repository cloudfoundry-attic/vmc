class TrackingExpector
  attr_reader :output

  def initialize(out, debug = false)
    @out = out
    @debug = debug
    @unused = ""
    @output = ""
  end

  def expect(pattern, timeout = 5)
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
      elsif output_ended?(timeout)
        @unused = buffer
        break
      else
        c = @out.getc.chr
      end

      STDOUT.putc c if @debug

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

  private

  def output_ended?(timeout)
    (@out.is_a?(IO) && !IO.select([@out], nil, nil, timeout)) || @out.eof?
  end
end