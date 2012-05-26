require "thor"
require "interact"
require "yaml"

require "cfoundry"

require "vmc/constants"
require "vmc/cli/dots"
require "vmc/cli/better_help"


module VMC
  module Interactive
    include ::Interactive::Rewindable
    include Dots

    class InteractiveDefault
      attr_reader :method

      def initialize(query, cls, cmd, flag)
        # here be dragons
        #
        # MRI has no Proc -> Lambda, so this is kind of the only way to work
        # around Proc's "convenient" argument handling while keeping the
        # blocks evaluated on the Command instance

        @method = :"__interact_#{cmd}_#{flag}__"
        cls.queries.send(:define_method, @method, &query)
      end

      def to_s
        "(interaction)"
      end
    end

    def force?
      false
    end

    def ask(question, options = {})
      if force? and options.key?(:default)
        options[:default]
      else
        super
      end
    end

    def list_choices(choices, options)
      choices.each_with_index do |o, i|
        puts "#{c(i + 1, :green)}: #{o}"
      end
    end

    def input_state(options)
      CFState.new(options)
    end

    def prompt(question, options)
      value =
        case options[:default]
        when true
          "y"
        when false
          "n"
        when nil
          ""
        else
          options[:default].to_s
        end

      print "#{question}"
      print c("> ", :blue)

      unless value.empty?
        print "#{c(value, :black) + "\b" * value.size}"
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

    class CFState < Interactive::InputState
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

  class Command < Thor
    include Interactive
    extend BetterHelp

    class_option :proxy, :aliases => "-u", :desc => "Proxy user"

    class_option :verbose,
      :type => :boolean, :aliases => "-v", :desc => "Verbose"

    class_option :force,
      :type => :boolean, :aliases => "-f", :desc => "Force (no interaction)"

    class_option :simple_output,
      :type => :boolean, :desc => "Simplified output format."

    class_option :script, :type => :boolean, :aliases => "-s",
      :desc => "--simple-output and --force"

    class_option :trace, :type => :boolean, :aliases => "-t",
      :desc => "Show API requests and responses"

    class_option :color, :type => :boolean, :desc => "Colored output"

    def self.queries
      return @queries if @queries

      @queries = Module.new
      include @queries

      @queries
    end

    def self.flag(name, options = {}, &query)
      if query
        options[:default] ||=
          InteractiveDefault.new(query, self, @usage.split.first, name)
      end

      method_option(name, options)
    end

    def self.callbacks_for(name)
      cs = callbacks[name]
      if superclass.respond_to? :callbacks
        cs.merge superclass.callbacks_for(name)
      else
        cs
      end
    end

    def self.callbacks
      @callbacks ||= Hash.new do |h, name|
        h[name] = Hash.new do |h, task|
          h[task] = []
        end
      end
    end

    def self.add_callback(name, task, callback)
      callbacks[name][task] << callback
    end

    def self.before(task, &callback)
      add_callback(:before, task, callback)
    end

    def self.after(task, &callback)
      add_callback(:after, task, callback)
    end

    def self.ensuring(task, &callback)
      add_callback(:ensuring, task, callback)
    end

    def self.around(task, &callback)
      add_callback(:around, task, callback)
    end

    private

    def callbacks_for(what)
      self.class.callbacks_for(what)
    end

    def passed_value(flag)
      if (val = options[flag]) && \
          !val.is_a?(VMC::Interactive::InteractiveDefault)
        val
      end
    end

    def input(name, *args)
      @inputs ||= {}
      return @inputs[name] if @inputs.key?(name)

      val = options[name]
      @inputs[name] =
        if val.is_a?(VMC::Interactive::InteractiveDefault)
          send(val.method, *args)
        elsif val.respond_to? :to_proc
          instance_exec(*args, &options[name])
        else
          options[name]
        end
    end

    def forget(name)
      @inputs.delete name
    end

    def script?
      if options.key?("script")
        options["script"]
      else
        !$stdout.tty?
      end
    end

    def force?
      if options.key?("force")
        options["force"]
      else
        script?
      end
    end

    def verbose?
      options["verbose"]
    end

    def simple_output?
      if options.key?("simple_output")
        options["simple_output"]
      else
        script?
      end
    end

    def color?
      if options.key?("color")
        options["color"]
      else
        !simple_output?
      end
    end

    def err(msg, exit_status = 1)
      if script?
        $stderr.puts(msg)
      else
        puts c(msg, :red)
      end

      $exit_status = 1
    end

    def invoke_task(task, args)
      callbacks_for(:before)[task.name.to_sym].each do |c|
        c.call
      end

      action = proc do |*new_args|
        if new_args.empty?
          task.run(self, args)
        elsif new_args.first.is_a? Array
          task.run(self, new_args.first)
        else
          task.run(self, new_args)
        end
      end

      callbacks_for(:around)[task.name.to_sym].each do |a|
        before = action
        action = proc do |passed_args|
          # with more than one wrapper, when the outer wrapper passes args to
          # inner wrapper, which calls the next inner with no args, it should
          # get the args passed to it by outer
          args = passed_args if passed_args
          instance_exec(before, args, &a)
        end
      end

      res = instance_exec(args, &action)

      callbacks_for(:after)[task.name.to_sym].each do |c|
        c.call
      end

      res
    rescue Interrupt
      $exit_status = 130
    rescue Thor::Error
      raise
    rescue Exception => e
      msg = e.class.name
      msg << ": #{e}" unless e.to_s.empty?
      err msg

      ensure_config_dir

      File.open(File.expand_path(VMC::CRASH_FILE), "w") do |f|
        f.print "Time of crash:\n  "
        f.puts Time.now
        f.puts ""
        f.puts msg
        f.puts ""

        e.backtrace.each do |loc|
          if loc =~ /\/gems\//
            f.puts loc.sub(/.*\/gems\//, "")
          else
            f.puts loc.sub(File.expand_path("../../../..", __FILE__) + "/", "")
          end
        end
      end
    ensure
      callbacks_for(:ensuring)[task.name.to_sym].each do |c|
        c.call
      end
    end
    public :invoke_task

    def sane_target_url(url)
      unless url =~ /^https?:\/\//
        url = "http://#{url}"
      end

      url.gsub(/\/$/, "")
    end

    def target_file
      one_of(VMC::TARGET_FILE, VMC::OLD_TARGET_FILE)
    end

    def tokens_file
      one_of(VMC::TOKENS_FILE, VMC::OLD_TOKENS_FILE)
    end

    def one_of(*paths)
      paths.each do |p|
        exp = File.expand_path(p)
        return exp if File.exist? exp
      end

      paths.first
    end

    def client_target
      File.read(target_file).chomp
    end

    def ensure_config_dir
      config = File.expand_path(VMC::CONFIG_DIR)
      Dir.mkdir(config) unless File.exist? config
    end

    def set_target(url)
      ensure_config_dir

      File.open(File.expand_path(VMC::TARGET_FILE), "w") do |f|
        f.write(sane_target_url(url))
      end

      @client = nil
    end

    def tokens
      new_toks = File.expand_path(VMC::TOKENS_FILE)
      old_toks = File.expand_path(VMC::OLD_TOKENS_FILE)

      if File.exist? new_toks
        YAML.load_file(new_toks)
      elsif File.exist? old_toks
        JSON.load(File.read(old_toks))
      else
        {}
      end
    end

    def client_token
      tokens[client_target]
    end

    def save_tokens(ts)
      ensure_config_dir

      File.open(File.expand_path(VMC::TOKENS_FILE), "w") do |io|
        YAML.dump(ts, io)
      end
    end

    def save_token(token)
      ts = tokens
      ts[client_target] = token
      save_tokens(ts)
    end

    def remove_token
      ts = tokens
      ts.delete client_target
      save_tokens(ts)
    end

    def client
      return @client if @client

      @client = CFoundry::Client.new(client_target, client_token)
      @client.proxy = options[:proxy]
      @client.trace = options[:trace]
      @client
    end

    def usage(used, limit)
      "#{b(human_size(used))} of #{b(human_size(limit, 0))}"
    end

    def percentage(num, low = 50, mid = 70)
      color =
        if num <= low
          :green
        elsif num <= mid
          :yellow
        else
          :red
        end

      c(format("%.1f\%", num), color)
    end

    def megabytes(str)
      if str =~ /T$/i
        str.to_i * 1024 * 1024
      elsif str =~ /G$/i
        str.to_i * 1024
      elsif str =~ /M$/i
        str.to_i
      elsif str =~ /K$/i
        str.to_i / 1024
      end
    end

    def human_size(num, precision = 1)
      sizes = ["G", "M", "K"]
      sizes.each.with_index do |suf, i|
        pow = sizes.size - i
        unit = 1024 ** pow
        if num >= unit
          return format("%.#{precision}f%s", num / unit, suf)
        end
      end

      format("%.#{precision}fB", num)
    end
  end
end
