module VMC
  module Dots
    DOT_COUNT = 3
    DOT_TICK = 0.15

    class Skipper
      def initialize(&ret)
        @return = ret
      end

      def skip(&callback)
        @return.call("SKIPPED", :yellow, callback)
      end

      def give_up(&callback)
        @return.call("GAVE UP", :red, callback)
      end

      def fail(&callback)
        @return.call("FAILED", :red, callback)
      end
    end

    def with_progress(message)
      unless simple_output?
        print message
        dots!
      end

      skipper = Skipper.new do |status, color, callback|
        unless simple_output?
          stop_dots!
          puts "... #{c(status, color)}"
        end

        return callback && callback.call
      end

      begin
        res = yield skipper
        unless simple_output?
          stop_dots!
          puts "... #{c("OK", :green)}"
        end
        res
      rescue
        unless simple_output?
          stop_dots!
          puts "... #{c("FAILED", :red)}"
        end

        raise
      end
    end

    def color?
      $stdout.tty?
    end

    COLOR_CODES = {
      :black => 0,
      :red => 1,
      :green => 2,
      :yellow => 3,
      :blue => 4,
      :magenta => 5,
      :cyan => 6,
      :white => 7
    }

    # colored text
    #
    # shouldn't use bright colors, as some color themes abuse
    # the bright palette (I'm looking at you, Solarized)
    def c(str, color)
      return str unless color?
      "\e[3#{COLOR_CODES[color]}m#{str}\e[0m"
    end
    module_function :c

    # bold text
    def b(str)
      return str unless color?
      "\e[1m#{str}\e[0m"
    end
    module_function :b

    def dots!
      @dots ||=
        Thread.new do
          before_sync = $stdout.sync

          $stdout.sync = true

          printed = false
          i = 1
          until @stop_dots
            if printed
              print "\b" * DOT_COUNT
            end

            print ("." * i).ljust(DOT_COUNT)
            printed = true

            if i == DOT_COUNT
              i = 0
            else
              i += 1
            end

            sleep DOT_TICK
          end

          if printed
            print "\b" * DOT_COUNT
            print " " * DOT_COUNT
            print "\b" * DOT_COUNT
          end

          $stdout.sync = before_sync
          @stop_dots = nil
        end
    end

    def stop_dots!
      return unless @dots
      return if @stop_dots
      @stop_dots = true
      @dots.join
      @dots = nil
    end
  end
end
