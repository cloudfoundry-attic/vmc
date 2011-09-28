module VMCExtensions

  def say(message)
    VMC::Cli::Config.output.puts(message) if VMC::Cli::Config.output
  end

  def header(message, filler = '-')
    say "\n"
    say message
    say filler.to_s * message.size
  end

  def banner(message)
    say "\n"
    say message
  end

  def display(message, nl=true)
    if nl
      say message
    else
      if VMC::Cli::Config.output
        VMC::Cli::Config.output.print(message)
        VMC::Cli::Config.output.flush
      end
    end
  end

  def clear(size=80)
    return unless VMC::Cli::Config.output
    VMC::Cli::Config.output.print("\r")
    VMC::Cli::Config.output.print(" " * size)
    VMC::Cli::Config.output.print("\r")
    #VMC::Cli::Config.output.flush
  end

  def err(message, prefix='Error: ')
    raise VMC::Cli::CliExit, "#{prefix}#{message}"
  end

  def warn(msg)
    say "#{"[WARNING]".yellow} #{msg}"
  end

  def quit(message = nil)
    raise VMC::Cli::GracefulExit, message
  end

  def blank?
    self.to_s.blank?
  end

  def uptime_string(delta)
    num_seconds = delta.to_i
    days = num_seconds / (60 * 60 * 24);
    num_seconds -= days * (60 * 60 * 24);
    hours = num_seconds / (60 * 60);
    num_seconds -= hours * (60 * 60);
    minutes = num_seconds / 60;
    num_seconds -= minutes * 60;
    "#{days}d:#{hours}h:#{minutes}m:#{num_seconds}s"
  end

  def pretty_size(size, prec=1)
    return 'NA' unless size
    return "#{size}B" if size < 1024
    return sprintf("%.#{prec}fK", size/1024.0) if size < (1024*1024)
    return sprintf("%.#{prec}fM", size/(1024.0*1024.0)) if size < (1024*1024*1024)
    return sprintf("%.#{prec}fG", size/(1024.0*1024.0*1024.0))
  end

  # general-purpose interaction
  #
  # `question' is the prompt (without ": " at the end)
  # `options' is a hash containing:
  #   :input - the input source (defaults to STDIN)
  #   :default - the default value, also used to attempt type conversion
  #              of the answer (e.g. numeric/boolean)
  #   :choices - a list of strings to choose from
  #   :indexed - whether to allow choosing from `:choices' by their index,
  #              best for when there are many choices
  #   :echo - a string to echo when showing the input;
  #           used for things like censoring password inpt
  #   :callback - a block used to override certain actions
  #
  #               takes 4 arguments:
  #                 action: the event, e.g. :up or [:key, X] where X is a
  #                         string containing a single character
  #                 answer: the current answer to the question; you'll
  #                         probably mutate this
  #                 position: the current offset from the start of the
  #                           answer string, e.g. when typing in the middle
  #                           of the input, this will be where you insert
  #                           characters
  #                 echo: the :echo option above, may be nil
  #
  #               the block should return the updated `position', or nil if
  #               it didn't handle the event
  def ask(question, options = {})
    default = options[:default]
    choices = options[:choices]
    indexed = options[:indexed]
    callback = options[:callback]
    input = options[:input] || STDIN
    echo = options[:echo]

    if choices
      VMCExtensions.ask_choices(input, question, default, choices, indexed, echo, &callback)
    else
      VMCExtensions.ask_default(input, question, default, echo, &callback)
    end
  end

  ESCAPES = {
    "[A" => :up, "H" => :up,
    "[B" => :down, "P" => :down,
    "[C" => :right, "M" => :right,
    "[D" => :left, "K" => :left,
    "[3~" => :delete, "S" => :delete,
    "[H" => :home, "G" => :home,
    "[F" => :end, "O" => :end
  }

  def handle_action(which, ans, pos, echo = nil)
    if block_given?
      res = yield which, ans, pos, echo
      return res unless res.nil?
    end

    case which
    when :up
      # nothing

    when :down
      # nothing

    when :tab
      # nothing

    when :right
      unless pos == ans.size
        display censor(ans[pos .. pos], echo), false
        return pos + 1
      end

    when :left
      unless pos == 0
        display "\b", false
        return pos - 1
      end

    when :delete
      unless pos == ans.size
        ans.slice!(pos, 1)
        if WINDOWS
          rest = ans[pos .. -1]
          display(censor(rest, echo) + " \b" + ("\b" * rest.size), false)
        else
          display("\e[P", false)
        end
      end

    when :home
      display("\b" * pos, false)
      return 0

    when :end
      display(censor(ans[pos .. -1], echo), false)
      return ans.size

    when :backspace
      if pos > 0
        ans.slice!(pos - 1, 1)

        if WINDOWS
          rest = ans[pos - 1 .. -1]
          display("\b" + censor(rest, echo) + " \b" + ("\b" * rest.size), false)
        else
          display("\b\e[P", false)
        end

        return pos - 1
      end

    when :interrupt
      raise Interrupt.new

    when :eof
      return false if ans.empty?

    when :kill_word
      if pos > 0
        start = /[^\s]*\s*$/ =~ ans[0 .. pos]
        length = pos - start
        ans.slice!(start, length)
        display("\b" * length + " " * length + "\b" * length, false)
        return start
      end

    when Array
      case which[0]
      when :key
        c = which[1]
        rest = ans[pos .. -1]

        ans.insert(pos, c)

        display(censor(c + rest, echo) + ("\b" * rest.size), false)

        return pos + 1
      end
    end

    pos
  end

  def censor(str, with)
    return str unless with
    with * str.size
  end

  # ask a simple question, maybe with a default answer
  #
  # reads character-by-character, handling backspaces, and sending each
  # character to a block if provided
  def self.ask_default(input, question, default = nil, echo = nil, &callback)
    while true
      prompt(question, default)

      ans = ""
      pos = 0
      escaped = false
      escape_seq = ""

      with_char_io(input) do
        until pos == false or (c = get_character(input)) =~ /[\r\n]/
          if c == "\e" || c == "\xE0"
            escaped = true
          elsif escaped
            escape_seq << c

            if cmd = ESCAPES[escape_seq]
              pos = handle_action(cmd, ans, pos, echo, &callback)
              escaped, escape_seq = false, ""
            elsif ESCAPES.select { |k, v| k.start_with? escape_seq }.empty?
              escaped, escape_seq = false, ""
            end
          elsif c == "\177" or c == "\b" # backspace
            pos = handle_action(:backspace, ans, pos, echo, &callback)
          elsif c == "\x01"
            pos = handle_action(:home, ans, pos, echo, &callback)
          elsif c == "\x03"
            pos = handle_action(:interrupt, ans, pos, echo, &callback)
          elsif c == "\x04"
            pos = handle_action(:eof, ans, pos, echo, &callback)
          elsif c == "\x05"
            pos = handle_action(:end, ans, pos, echo, &callback)
          elsif c == "\x17"
            pos = handle_action(:kill_word, ans, pos, echo, &callback)
          elsif c == "\t"
            pos = handle_action(:tab, ans, pos, echo, &callback)
          elsif c < " "
            # ignore
          else
            pos = handle_action([:key, c], ans, pos, echo, &callback)
          end
        end
      end

      display "\n", false

      if ans.empty?
        return default unless default.nil?
      else
        return match_type(ans, default)
      end
    end
  end

  def self.ask_choices(input, question, default, choices, indexed = false, echo = nil, &callback)
    msg = question.dup

    if indexed
      choices.each.with_index do |o, i|
        say "#{i + 1}: #{o}"
      end
    else
      msg << " (#{choices.collect(&:inspect).join ", "})"
    end

    while true
      ans = ask_default(input, msg, default, echo, &callback)

      matches = choices.select { |x| x.start_with? ans }

      if matches.size == 1
        return matches.first
      elsif indexed and ans =~ /^\d+$/ and res = choices.to_a[ans.to_i - 1]
        return res
      elsif matches.size > 1
        warn "Please disambiguate: #{matches.join " or "}?"
      else
        warn "Unknown answer, please try again!"
      end
    end
  end

  # display a question and show the default value
  def self.prompt(question, default = nil)
    msg = question.dup

    case default
    when true
      msg << " [Yn]"
    when false
      msg << " [yN]"
    else
      msg << " [#{default.inspect}]" if default
    end

    display "#{msg}: ", false
  end

  # try to make `str' be the same class as `x'
  def self.match_type(str, x)
    case x
    when Integer
      str.to_i
    when true, false
      str.upcase.start_with? "Y"
    else
      str
    end
  end

  # definitions for reading character-by-character
  begin
    require "Win32API"

    def self.with_char_io(input)
      yield
    end

    def self.get_character(input)
      if input == STDIN
        begin
          Win32API.new("msvcrt", "_getch", [], "L").call.chr
        rescue
          Win32API.new("crtdll", "_getch", [], "L").call.chr
        end
      else
        input.getc.chr
      end
    end
  rescue LoadError
    begin
      require "termios"

      def self.with_char_io(input)
        return yield unless input.tty?

        before = Termios.getattr(input)

        new = before.dup
        new.c_lflag &= ~(Termios::ECHO | Termios::ICANON)
        new.c_cc[Termios::VMIN] = 1

        begin
          Termios.setattr(input, Termios::TCSANOW, new)
          yield
        ensure
          Termios.setattr(input, Termios::TCSANOW, before)
        end
      end

      def self.get_character(input)
        input.getc.chr
      end
    rescue LoadError
      # set tty modes for the duration of a block, restoring them afterward
      def self.with_char_io(input)
        return yield unless input.tty?

        begin
          before = `stty -g`
          system("stty raw -echo -icanon isig")
          yield
        ensure
          system("stty #{before}")
        end
      end

      # this assumes we're wrapped in #with_stty
      def self.get_character(input)
        input.getc.chr
      end
    end
  end
end

module VMCStringExtensions

  def red
    colorize("\e[0m\e[31m")
  end

  def green
    colorize("\e[0m\e[32m")
  end

  def yellow
    colorize("\e[0m\e[33m")
  end

  def bold
    colorize("\e[0m\e[1m")
  end

  def colorize(color_code)
    if VMC::Cli::Config.colorize
      "#{color_code}#{self}\e[0m"
    else
      self
    end
  end

  def blank?
    self =~ /^\s*$/
  end

  def truncate(limit = 30)
    return "" if self.blank?
    etc = "..."
    stripped = self.strip[0..limit]
    if stripped.length > limit
      stripped.gsub(/\s+?(\S+)?$/, "") + etc
    else
      stripped
    end
  end

end

class Object
  include VMCExtensions
end

class String
  include VMCStringExtensions
end
