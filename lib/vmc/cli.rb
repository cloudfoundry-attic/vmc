require "yaml"
require "socket"
require "net/http"

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

    option :proxy, :alias => "-u", :value => :email,
      :desc => "Act as another user (admin only)"

    option :version, :alias => "-v", :type => :boolean,
      :desc => "Print version number"

    option(:force, :alias => "-f", :type => :boolean,
           :desc => "Skip interaction when possible") {
      option(:script)
    }

    option(:quiet, :alias => "-q", :type => :boolean,
           :desc => "Simplify output format") {
      option(:script)
    }

    option(:script, :type => :boolean,
           :desc => "Shortcut for --quiet and --force") {
      !$stdout.tty?
    }

    option(:color, :type => :boolean, :default => true,
           :desc => "Use colorful output") {
      !option(:quiet)
    }

    option :trace, :alias => "-t", :type => :boolean,
      :desc => "Show API requests and responses"


    def default_action
      if option(:version)
        puts "vmc #{VERSION}"
      else
        super
      end
    end

    def precondition
      unless client.logged_in?
        fail "Please log in with 'vmc login'."
      end

      return unless v2?

      unless client.current_organization
        fail "Please select an organization with 'vmc target -i'."
      end

      unless client.current_space
        fail "Please select a space with 'vmc target -i'."
      end
    end

    def execute(cmd, argv)
      if option(:help)
        invoke :help, :command => cmd.name.to_s
      else
        cmd.context.new.precondition if cmd.context <= CLI
        super
      end
    rescue Interrupt
      exit_status 130
    rescue Mothership::Error
      raise
    rescue UserError => e
      log_error(e)
      err e.message
    rescue CFoundry::Denied => e
      if !$vmc_asked_auth && e.error_code == 200
        $vmc_asked_auth = true

        puts ""
        puts c("Not authenticated! Try logging in:", :warning)

        invoke :login

        retry
      end

      log_error(e)

      err "Denied: #{e.description}"

    rescue Exception => e
      ensure_config_dir

      log_error(e)

      msg = e.class.name
      msg << ": #{e}" unless e.to_s.empty?
      err msg
    end

    def log_error(e)
      msg = e.class.name
      msg << ": #{e}" unless e.to_s.empty?

      File.open(File.expand_path(VMC::CRASH_FILE), "w") do |f|
        f.puts "Time of crash:"
        f.puts "  #{Time.now}"
        f.puts ""
        f.puts msg
        f.puts ""

        vmc_dir = File.expand_path("../../../..", __FILE__) + "/"
        e.backtrace.each do |loc|
          if loc =~ /\/gems\//
            f.puts loc.sub(/.*\/gems\//, "")
          else
            f.puts loc.sub(vmc_dir, "")
          end
        end
      end
    end

    def quiet?
      option(:quiet)
    end

    def force?
      option(:force)
    end

    def color_enabled?
      option(:color)
    end

    def err(msg, status = 1)
      if quiet?
        $stderr.puts(msg)
      else
        puts c(msg, :error)
      end

      exit_status status
    end

    def fail(msg)
      raise UserError, msg
    end

    def sane_target_url(url)
      unless url =~ /^https?:\/\//
        begin
          TCPSocket.new(url, Net::HTTP.https_default_port)
          url = "https://#{url}"
        rescue SocketError, Timeout::Error
          url = "http://#{url}"
        end
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

      invalidate_client
    end

    def targets_info
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

    def target_info
      info = targets_info[client_target]

      if info.is_a? String
        { :token => info }
      else
        info || {}
      end
    end

    def save_targets(ts)
      ensure_config_dir

      File.open(File.expand_path(VMC::TOKENS_FILE), "w") do |io|
        YAML.dump(ts, io)
      end
    end

    def save_target_info(info)
      ts = targets_info
      ts[client_target] = info
      save_targets(ts)
    end

    def remove_target_info
      ts = targets_info
      ts.delete client_target
      save_targets(ts)
    end

    def no_v2
      fail "Not implemented for v2." if v2?
    end

    def v2?
      client.is_a?(CFoundry::V2::Client)
    end

    def invalidate_client
      @@client = nil
      client
    end

    def client
      return @@client if defined?(@@client) && @@client

      info = target_info

      @@client =
        case info[:version]
        when 2
          CFoundry::V2::Client.new(client_target, info[:token])
        when 1
          CFoundry::V1::Client.new(client_target, info[:token])
        else
          CFoundry::Client.new(client_target, info[:token])
        end

      @@client.proxy = option(:proxy)
      @@client.trace = option(:trace)

      info[:version] ||=
        case @@client
        when CFoundry::V2::Client
          2
        else
          1
        end

      if org = info[:organization]
        @@client.current_organization = @@client.organization(org)
      end

      if space = info[:space]
        @@client.current_space = @@client.space(space)
      end

      save_target_info(info)

      @@client
    end

    class << self
      def client
        @@client
      end

      def client=(c)
        @@client = c
      end
    end
  end
end
