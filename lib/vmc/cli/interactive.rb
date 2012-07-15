require "interact"

module VMC
  module Interactive
    include ::Interactive::Rewindable

    def ask(question, options = {})
      if force? and options.key?(:default)
        options[:default]
      else
        super
      end
    end

    def list_choices(choices, options = {})
      choices.each_with_index do |o, i|
        puts "#{c(i + 1, :number)}: #{show_choice(o, options)}"
      end
    end

    def input_state(options)
      if options.key? :default
        answer = show_default(options)
      end

      CFState.new(options, answer)
    end

    def show_default(options)
      case options[:default]
      when true
        "y"
      when false
        "n"
      when nil
        ""
      else
        show_choice(options[:default], options)
      end
    end

    def prompt(question, options)
      value = show_default(options)

      print "#{question}"
      print c("> ", :prompt)

      unless value.empty?
        print "#{c(value, :default) + "\b" * value.size}"
      end
    end

    def handler(which, state)
      ans = state.answer
      pos = state.position

      if state.default?
        if which.is_a?(Array) and which[0] == :key
          # initial non-movement keypress clears default answer
          clear_input(state)
        else
          # wipe away any coloring
          redraw_input(state)
        end

        state.clear_default!
      end

      super

      print "\n" if which == :enter
    end

    class CFState < ::Interactive::InputState
      def initialize(options = {}, answer = nil, position = 0)
        @options = options

        if answer
          @answer = answer
        elsif options[:default]
          case options[:default]
          when true
            @answer = "y"
          when false
            @answer = "n"
          else
            # TODO: hacky
            @answer = options[:default].to_s
          end

          @default = true
        else
          @answer = ""
        end

        @position = position
        @done = false
      end

      def clear_default!
        @default = false
      end

      def default?
        @default
      end
    end
  end
end
