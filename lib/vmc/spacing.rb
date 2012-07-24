module VMC
  module Spacing
    @@indentation = 0

    def indented
      @@indentation += 1
      yield
    ensure
      @@indentation -= 1
    end

    def line(msg = "")
      return puts "" if msg.empty?

      start_line(msg)
      puts ""
    end

    def start_line(msg)
      print "  " * @@indentation
      print msg
    end

    def lines(blob)
      blob.each_line do |line|
        start_line(line)
      end

      line
    end

    def quiet?
      false
    end

    def spaced(vals)
      num = 0
      vals.each do |val|
        line unless quiet? || num == 0
        yield val
        num += 1
      end
    end
  end
end
