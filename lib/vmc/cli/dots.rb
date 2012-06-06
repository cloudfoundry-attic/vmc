require "rbconfig"

module VMC
  module Dots
    DOT_COUNT = 3
    DOT_TICK = 0.15

    class Skipper
      def initialize(&ret)
        @return = ret
      end

      def skip(&callback)
        @return.call("SKIPPED", :warning, callback)
      end

      def give_up(&callback)
        @return.call("GAVE UP", :bad, callback)
      end

      def fail(&callback)
        @return.call("FAILED", :error, callback)
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
          puts "... #{c("OK", :good)}"
        end
        res
      rescue
        unless simple_output?
          stop_dots!
          puts "... #{c("FAILED", :error)}"
        end

        raise
      end
    end

    WINDOWS = !!(RbConfig::CONFIG['host_os'] =~ /mingw|mswin32|cygwin/)

    def color?
      !WINDOWS && $stdout.tty?
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

    DEFAULT_COLORS = {
      :name => :blue,
      :neutral => :blue,
      :good => :green,
      :bad => :red,
      :error => :magenta,
      :unknown => :cyan,
      :warning => :yellow,
      :instance => :yellow,
      :number => :green,
      :prompt => :blue,
      :yes => :green,
      :no => :red
    }

    def user_colors
      return @user_colors if @user_colors

      colors = File.expand_path VMC::COLORS_FILE

      if File.exists? colors
        @user_colors = DEFAULT_COLORS.dup

        YAML.load_file(colors).each do |k, v|
          if k == true
            k = :yes
          elsif k == false
            k = :no
          else
            k = k.to_sym
          end

          @user_colors[k] = v.to_sym
        end

        @user_colors
      else
        @user_colors = DEFAULT_COLORS
      end
    end

    # colored text
    #
    # shouldn't use bright colors, as some color themes abuse
    # the bright palette (I'm looking at you, Solarized)
    def c(str, type)
      return str unless color?

      bright = false
      color = user_colors[type]
      if color =~ /bright-(.+)/
        bright = true
        color = $1.to_sym
      end

      return str unless color

      "\e[#{bright ? 9 : 3}#{COLOR_CODES[color]}m#{str}\e[0m"
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
