module VMC::Cli::Command
  class Micro < Base

    def initialize(args)
      super(args)
    end

    def offline(mode)
      command('offline')
    end

    def online(mode)
      command('online')
    end

    def status(mode)
      command('status')
    end

    def command(cmd)
      config = build_config
      switcher(config).send(cmd)
      store_config(config)
    end

    def switcher(config)
      case Micro.platform
      when :darwin
        switcher = VMC::Micro::Switcher::Darwin.new(config)
      when :linux
        switcher = VMC::Micro::Switcher::Linux.new(config)
      when :windows
        switcher = VMC::Micro::Switcher::Windows.new(config)
      when :dummy # for testing only
        switcher = VMC::Micro::Switcher::Dummy.new(config)
      else
        err "unsupported platform: #{Micro.platform}"
      end
    end

    # Returns the configuration needed to run the micro related subcommands.
    # First loads saved config from file (if there is any), then overrides
    # loaded values with command line arguments, and finally tries to guess
    # in case neither was used:
    #   vmx       location of micro.vmx file
    #   vmrun     location of vmrun command
    #   password  password for vcap user (in the guest vm)
    #   platform  current platform
    def build_config
      conf = VMC::Cli::Config.micro # returns {} if there isn't a saved config

      override(conf, 'vmx', true) do
        locate_vmx(Micro.platform)
      end

      override(conf, 'vmrun', true) do
        VMC::Micro::VMrun.locate(Micro.platform)
      end

      override(conf, 'password') do
        @password = ask("Please enter your Micro Cloud Foundry VM password (vcap user) password", :echo => "*")
      end

      conf['platform'] = Micro.platform

      conf
    end

    # Save the cleartext password if --save is supplied.
    # Note: it is due to vix we have to use a cleartext password :(
    # Only if --password is used and not --save is the password deleted from the
    # config file before it is stored to disk.
    def store_config(config)
      if @options[:save]
        warn("cleartext password saved in: #{VMC::Cli::Config::MICRO_FILE}")
      elsif @options[:password] || @password
        config.delete('password')
      end

      VMC::Cli::Config.store_micro(config)
    end

    # override with command line arguments and yield the block in case the option isn't set
    def override(config, option, escape=false, &blk)
      # override if given on the command line
      if opt = @options[option.to_sym]
        opt = VMC::Micro.escape_path(opt) if escape
        config[option] = opt
      end
      config[option] = yield unless config[option]
    end

    def locate_vmx(platform)
      paths = YAML.load_file(VMC::Micro.config_file('paths.yml'))
      vmx_paths = paths[platform.to_s]['vmx']
      vmx = VMC::Micro.locate_file('micro.vmx', 'micro', vmx_paths)
      err "Unable to locate micro.vmx, please supply --vmx option" unless vmx
      vmx
    end

    def self.platform
      case RUBY_PLATFORM
      when /darwin/  # x86_64-darwin11.2.0
        :darwin
      when /linux/   # x86_64-linux
        :linux
      when /mingw|mswin32|cygwin/ # i386-mingw32
        :windows
      else
        RUBY_PLATFORM
      end
    end

  end
end
