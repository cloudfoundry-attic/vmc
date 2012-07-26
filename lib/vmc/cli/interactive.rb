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
        print "#{d(value) + "\b" * value.size}"
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

        # tab with a default accepts it and moves to the end
        if which == :tab
          state.goto(ans.size)
        else
          super
        end
      else
        super
      end

      print "\n" if which == :enter
    end

    class CFState < ::Interactive::InputState
      def initialize(options = {}, answer = nil, position = 0)
        @options = options
        @answer = answer || ""
        @default = options.key? :default
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
