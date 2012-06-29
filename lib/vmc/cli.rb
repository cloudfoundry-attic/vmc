require "yaml"

require "mothership"
require "mothership/pretty"
require "mothership/progress"

require "cfoundry"

require "vmc/constants"
require "vmc/errors"

require "vmc/cli/help"
require "vmc/cli/interactive"


$vmc_asked_auth = false

module VMC
  class CLI < Mothership
    include VMC::Interactive
    include Mothership::Pretty
    include Mothership::Progress

    option :help, :alias => "-h", :type => :boolean,
      :desc => "Show command usage & instructions"

    option :proxy, :alias => "-u",
      :desc => "Act as another user (admin only)"

    option :version, :alias => "-v", :type => :boolean,
      :desc => "Print version number"

    option :force, :alias => "-f", :type => :boolean,
      :desc => "Skip interaction when possible"

    option :simple_output, :alias => "-q", :type => :boolean,
      :desc => "Simplify output format"

    option :script, :alias => "-s", :type => :boolean,
      :desc => "Shortcut for --simple-output and --force"

    option :trace, :alias => "-t", :type => :boolean,
      :desc => "Show API requests and responses"

    option :color, :type => :boolean, :desc => "Use colorful output"


    def default_action
      if option(:version)
        puts "vmc #{VERSION}"
      else
        super
      end
    end

    def execute(cmd, argv)
      if option(:help)
        invoke :help, :command => cmd.name.to_s
      else
        super
      end
    rescue Interrupt
      exit_status 130
    rescue Mothership::Error
      raise
    rescue UserError => e
      err e.message
    rescue CFoundry::Denied => e
      if !$vmc_asked_auth && e.error_code == 200
        $vmc_asked_auth = true

        puts ""
        puts c("Not authenticated! Try logging in:", :warning)

        invoke :login
        @client = nil

        retry
      end

      err "Denied: #{e.description}"
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
    end

    def script?
      if option_given?(:script)
        option(:script)
      else
        !$stdout.tty?
      end
    end

    def force?
      if option_given?(:force)
        option(:force)
      else
        script?
      end
    end

    def simple_output?
      if option_given?(:simple_output)
        option(:simple_output)
      else
        script?
      end
    end

    def color_enabled?
      if option_given?(:color)
        option(:color)
      else
        !simple_output?
      end
    end

    def err(msg, exit_status = 1)
      if script?
        $stderr.puts(msg)
      else
        puts c(msg, :error)
      end

      exit_status 1
    end

    def fail(msg)
      raise UserError, msg
    end

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
      @client.proxy = option(:proxy)
      @client.trace = option(:trace)
      @client
    end

    def usage(used, limit)
      "#{b(human_size(used))} of #{b(human_size(limit, 0))}"
    end

    def percentage(num, low = 50, mid = 70)
      color =
        if num <= low
          :good
        elsif num <= mid
          :warning
        else
          :bad
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
      else # assume megabytes
        str.to_i
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
