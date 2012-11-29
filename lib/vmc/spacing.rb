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
      print "  " * @@indentation unless quiet?
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

    def tabular(*rows)
      spacings = []
      rows.each do |row|
        next unless row

        row.each.with_index do |col, i|
          next unless col

          width = text_width(col)

          if !spacings[i] || width > spacings[i]
            spacings[i] = width
          end
        end
      end

      columns = spacings.size
      rows.each do |row|
        next unless row

        row.each.with_index do |col, i|
          next unless col

          start_line justify(col, spacings[i])
          print "   " unless i + 1 == columns
        end

        line
      end
    end

    def trim_escapes(str)
      str.gsub(/\e\[\d+m/, "")
    end

    def text_width(str)
      trim_escapes(str).size
    end

    def justify(str, width)
      trimmed = trim_escapes(str)
      str.ljust(width + (str.size - trimmed.size))
    end
  end
end
