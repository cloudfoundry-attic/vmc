
require 'optparse'

require File.dirname(__FILE__) + '/usage'

class VMC::Cli::Runner

  attr_reader   :namespace
  attr_reader   :action
  attr_reader   :args
  attr_reader   :options

  def self.run(args)
    new(args).run
  end

  def initialize(args=[])
    @args = args
    @options = { :colorize => true }
    @exit_status = true
  end

  # Collect all the available options for all commands
  # Some duplicates exists to capture all scenarios
  def parse_options!
    opts_parser = OptionParser.new do |opts|
      opts.banner = "\nAvailable options:\n\n"

      opts.on('--email EMAIL')     { |email| @options[:email] = email }
      opts.on('--user EMAIL')      { |email| @options[:email] = email }
      opts.on('--passwd PASS')     { |pass|  @options[:password] = pass }
      opts.on('--pass PASS')       { |pass|  @options[:password] = pass }
      opts.on('--password PASS')   { |pass|  @options[:password] = pass }
      opts.on('--token-file TOKEN_FILE')     { |token_file|  @options[:token_file] = token_file }
      opts.on('--app NAME')        { |name|  @options[:name] = name }
      opts.on('--name NAME')       { |name|  @options[:name] = name }
      opts.on('--bind BIND')       { |bind|  @options[:bind] = bind }
      opts.on('--instance INST')   { |inst|  @options[:instance] = inst }
      opts.on('--instances INST')  { |inst|  @options[:instances] = inst }
      opts.on('--url URL')         { |url|   @options[:url] = url }
      opts.on('--mem MEM')         { |mem|   @options[:mem] = mem }
      opts.on('--path PATH')       { |path|  @options[:path] = path }
      opts.on('--no-start')        {         @options[:nostart] = true }
      opts.on('--nostart')         {         @options[:nostart] = true }
      opts.on('--force')           {         @options[:force] = true }
      opts.on('--all')             {         @options[:all] = true }

      # generic tracing and debugging
      opts.on('-t [TKEY]')         { |tkey|  @options[:trace] = tkey || true }
      opts.on('--trace [TKEY]')    { |tkey|  @options[:trace] = tkey || true }

      # start application in debug mode
      opts.on('-d [MODE]')         { |mode|  @options[:debug] = mode || "run" }
      opts.on('--debug [MODE]')    { |mode|  @options[:debug] = mode || "run" }

      # override manifest file
      opts.on('-m FILE')           { |file|  @options[:manifest] = file }
      opts.on('--manifest FILE')   { |file|  @options[:manifest] = file }

      opts.on('-q', '--quiet')     {         @options[:quiet] = true }

      # micro cloud options
      opts.on('--vmx FILE')        { |file|  @options[:vmx] = file }
      opts.on('--vmrun FILE')      { |file|  @options[:vmrun] = file }
      opts.on('--save')            {         @options[:save] = true }

      # Don't use builtin zip
      opts.on('--no-zip')          {         @options[:nozip] = true }
      opts.on('--nozip')           {         @options[:nozip] = true }

      opts.on('--no-resources')    {         @options[:noresources] = true }
      opts.on('--noresources')     {         @options[:noresources] = true }

      opts.on('--no-color')        {         @options[:colorize] = false }
      opts.on('--verbose')         {         @options[:verbose] = true }

      opts.on('-n','--no-prompt')  {         @options[:noprompts] = true }
      opts.on('--noprompt')        {         @options[:noprompts] = true }
      opts.on('--non-interactive') {         @options[:noprompts] = true }

      opts.on('--prefix')          {         @options[:prefixlogs] = true }
      opts.on('--prefix-logs')     {         @options[:prefixlogs] = true }
      opts.on('--prefixlogs')      {         @options[:prefixlogs] = true }

      opts.on('--json')            {         @options[:json] = true }

      opts.on('-v', '--version')   {         set_cmd(:misc, :version) }
      opts.on('-h', '--help')      {         puts "#{command_usage}\n"; exit }

      opts.on('--port PORT')       { |port|  @options[:port] = port }

      opts.on('--runtime RUNTIME') { |rt|    @options[:runtime] = rt }

      # deprecated
      opts.on('--exec EXEC')       { |exec|  @options[:exec] = exec }
      opts.on('--noframework')     {         @options[:noframework] = true }
      opts.on('--canary')          {         @options[:canary] = true }

      # Proxying for another user, requires admin privileges
      opts.on('-u PROXY')          { |proxy| @options[:proxy] = proxy }

      opts.on_tail('--options')    {          puts "#{opts}\n"; exit }
    end
    instances_delta_arg = check_instances_delta!
    @args = opts_parser.parse!(@args)
    @args.concat instances_delta_arg
    convert_options!
    self
  end

  def check_instances_delta!
    return unless @args
    instance_args = @args.select { |arg| /^[-]\d+$/ =~ arg } || []
    @args.delete_if { |arg| instance_args.include? arg}
    instance_args
  end

  def display_help
    puts command_usage
    exit
  end

  def convert_options!
    # make sure certain options are valid and in correct form.
    @options[:instances] = Integer(@options[:instances]) if @options[:instances]
  end

  def set_cmd(namespace, action, args_range=0)
    return if @help_only
    unless args_range == "*" || args_range.is_a?(Range)
      args_range = (args_range.to_i..args_range.to_i)
    end

    if args_range == "*" || args_range.include?(@args.size)
      @namespace = namespace
      @action    = action
    else
      @exit_status = false
      if @args.size > args_range.last
        usage_error("Too many arguments for [#{action}]: %s" % [ @args[args_range.last..-1].map{|a| "'#{a}'"}.join(', ') ])
      else
        usage_error("Not enough arguments for [#{action}]")
      end
    end
  end

  def parse_command!
    # just return if already set, happends with -v, -h
    return if @namespace && @action

    verb = @args.shift
    case verb

    when 'version'
      usage('vmc version')
      set_cmd(:misc, :version)

    when 'target'
      usage('vmc target [url] [--url]')
      if @args.size == 1
        set_cmd(:misc, :set_target, 1)
      else
        set_cmd(:misc, :target)
      end

    when 'targets'
      usage('vmc targets')
      set_cmd(:misc, :targets)

    when 'tokens'
      usage('vmc tokens')
      set_cmd(:misc, :tokens)

    when 'info'
      usage('vmc info')
      set_cmd(:misc, :info)

    when 'runtimes'
      usage('vmc runtimes')
      set_cmd(:misc, :runtimes)

    when 'frameworks'
      usage('vmc frameworks')
      set_cmd(:misc, :frameworks)

    when 'user'
      usage('vmc user')
      set_cmd(:user, :info)

    when 'login'
      usage('vmc login [email] [--email EMAIL] [--passwd PASS]')
      if @args.size == 1
        set_cmd(:user, :login, 1)
      else
        set_cmd(:user, :login)
      end

    when 'logout'
      usage('vmc logout')
      set_cmd(:user, :logout)

    when 'passwd'
      usage('vmc passwd')
      if @args.size == 1
        set_cmd(:user, :change_password, 1)
      else
        set_cmd(:user, :change_password)
      end

    when 'add-user', 'add_user', 'create_user', 'create-user', 'register'
      usage('vmc add-user [user] [--email EMAIL] [--passwd PASS]')
      if @args.size == 1
        set_cmd(:admin, :add_user, 1)
      else
        set_cmd(:admin, :add_user)
      end

    when 'delete-user', 'delete_user', 'unregister'
      usage('vmc delete-user <user>')
      set_cmd(:admin, :delete_user, 1)

    when 'users'
      usage('vmc users')
      set_cmd(:admin, :users)

    when 'apps'
      usage('vmc apps')
      set_cmd(:apps, :apps)

    when 'list'
      usage('vmc list')
      set_cmd(:apps, :list)

    when 'start'
      usage('vmc start <appname>')
      set_cmd(:apps, :start, @args.size == 1 ? 1 : 0)

    when 'stop'
      usage('vmc stop <appname>')
      set_cmd(:apps, :stop, @args.size == 1 ? 1 : 0)

    when 'restart'
      usage('vmc restart <appname>')
      set_cmd(:apps, :restart, @args.size == 1 ? 1 : 0)

    when 'mem'
      usage('vmc mem <appname> [memsize]')
      if @args.size == 2
        set_cmd(:apps, :mem, 2)
      else
        set_cmd(:apps, :mem, 1)
      end

    when 'stats'
      usage('vmc stats <appname>')
      set_cmd(:apps, :stats, @args.size == 1 ? 1 : 0)

    when 'map'
      usage('vmc map <appname> <url>')
      set_cmd(:apps, :map, 2)

    when 'unmap'
      usage('vmc unmap <appname> <url>')
      set_cmd(:apps, :unmap, 2)

    when 'delete'
      usage('vmc delete <appname>')
      if @options[:all] && @args.size == 0
        set_cmd(:apps, :delete)
      else
        set_cmd(:apps, :delete, 1)
      end

    when 'files'
      usage('vmc files <appname> [path] [--instance N] [--all] [--prefix]')
      if @args.size == 1
        set_cmd(:apps, :files, 1)
      else
        set_cmd(:apps, :files, 2)
      end

    when 'logs'
      usage('vmc logs <appname> [--instance N] [--all] [--prefix]')
      set_cmd(:apps, :logs, 1)

    when 'instances', 'scale'
      if @args.size > 1
        usage('vmc instances <appname> <num|delta>')
        set_cmd(:apps, :instances, 2)
      else
        usage('vmc instances <appname>')
        set_cmd(:apps, :instances, 1)
      end

    when 'crashes'
      usage('vmc crashes <appname>')
      set_cmd(:apps, :crashes, 1)

    when 'crashlogs'
      usage('vmc crashlogs <appname>')
      set_cmd(:apps, :crashlogs, 1)

    when 'push'
      usage('vmc push [appname] [--path PATH] [--url URL] [--instances N] [--mem] [--runtime RUNTIME] [--no-start]')
      if @args.size == 1
        set_cmd(:apps, :push, 1)
      else
        set_cmd(:apps, :push, 0)
      end

    when 'update'
      usage('vmc update <appname> [--path PATH]')
      set_cmd(:apps, :update, @args.size == 1 ? 1 : 0)

    when 'services'
      usage('vmc services')
      set_cmd(:services, :services)

    when 'env'
      usage('vmc env <appname>')
      set_cmd(:apps, :environment, 1)

    when 'env-add'
      usage('vmc env-add <appname> <variable[=]value>')
      if @args.size == 2
        set_cmd(:apps, :environment_add, 2)
      elsif @args.size == 3
        set_cmd(:apps, :environment_add, 3)
      end

    when 'env-del'
      usage('vmc env-del <appname> <variable>')
      set_cmd(:apps, :environment_del, 2)

    when 'create-service', 'create_service'
      usage('vmc create-service [service] [servicename] [appname] [--name servicename] [--bind appname]')
      set_cmd(:services, :create_service) if @args.size == 0
      set_cmd(:services, :create_service, 1) if @args.size == 1
      set_cmd(:services, :create_service, 2) if @args.size == 2
      set_cmd(:services, :create_service, 3) if @args.size == 3

    when 'delete-service', 'delete_service'
      usage('vmc delete-service <service>')
      if @args.size == 1
        set_cmd(:services, :delete_service, 1)
      else
        set_cmd(:services, :delete_service)
      end

    when 'bind-service', 'bind_service'
      usage('vmc bind-service <servicename> <appname>')
      set_cmd(:services, :bind_service, 2)

    when 'unbind-service', 'unbind_service'
      usage('vmc unbind-service <servicename> <appname>')
      set_cmd(:services, :unbind_service, 2)

    when 'clone-services'
      usage('vmc clone-services <src-app> <dest-app>')
      set_cmd(:services, :clone_services, 2)

    when 'aliases'
      usage('vmc aliases')
      set_cmd(:misc, :aliases)

    when 'alias'
      usage('vmc alias <alias[=]command>')
      if @args.size == 1
        set_cmd(:misc, :alias, 1)
      elsif @args.size == 2
        set_cmd(:misc, :alias, 2)
      end

    when 'unalias'
      usage('vmc unalias <alias>')
      set_cmd(:misc, :unalias, 1)

    when 'tunnel'
      usage('vmc tunnel [servicename] [clientcmd] [--port port]')
      set_cmd(:services, :tunnel, 0) if @args.size == 0
      set_cmd(:services, :tunnel, 1) if @args.size == 1
      set_cmd(:services, :tunnel, 2) if @args.size == 2

    when 'rails-console'
      usage('vmc rails-console <appname>')
      set_cmd(:apps, :console, 1)

    when 'micro'
      usage('vmc micro <online|offline|status> [--password password] [--save] [--vmx file] [--vmrun executable]')
      if %w[online offline status].include?(@args[0])
          set_cmd(:micro, @args[0].to_sym, 1)
      end

    when 'help'
      display_help if @args.size == 0
      @help_only = true
      parse_command!

    when 'usage'
      display basic_usage
      exit(true)

    when 'options'
      # Simulate --options
      @args = @args.unshift('--options')
      parse_options!

    when 'manifest'
      usage('vmc manifest')
      set_cmd(:manifest, :edit)

    when 'extend-manifest'
      usage('vmc extend-manifest')
      set_cmd(:manifest, :extend, 1)

    else
      if verb
        display "vmc: Unknown command [#{verb}]"
        display basic_usage
        exit(false)
      end
    end
  end

  def process_aliases!
    return if @args.empty?
    aliases = VMC::Cli::Config.aliases
    aliases.each_pair do |k,v|
      if @args[0] == k
        display "[#{@args[0]} aliased to #{aliases.invert[key]}]" if @options[:verbose]
        @args[0] = v
        break;
      end
    end
  end

  def usage(msg = nil)
    @usage = msg if msg
    @usage
  end

  def usage_error(msg = nil)
    @usage_error = msg if msg
    @usage_error
  end

  def run

    trap('TERM') { print "\nTerminated\n"; exit(false)}

    parse_options!

    @options[:colorize] = false unless STDOUT.tty?

    VMC::Cli::Config.colorize   = @options.delete(:colorize)
    VMC::Cli::Config.nozip      = @options.delete(:nozip)
    VMC::Cli::Config.trace      = @options.delete(:trace)
    VMC::Cli::Config.output   ||= STDOUT unless @options[:quiet]

    process_aliases!
    parse_command!

    if @namespace && @action
      cmd = VMC::Cli::Command.const_get(@namespace.to_s.capitalize)
      cmd.new(@options).send(@action, *@args.collect(&:dup))
    elsif @help_only || @usage
      display_usage
    else
      display basic_usage
      exit(false)
    end

  rescue OptionParser::InvalidOption => e
    puts(e.message.red)
    puts("\n")
    puts(basic_usage)
    @exit_status = false
  rescue OptionParser::AmbiguousOption => e
    puts(e.message.red)
    puts("\n")
    puts(basic_usage)
    @exit_status = false
  rescue VMC::Client::AuthError => e
    if VMC::Cli::Config.auth_token.nil?
      puts "Login Required".red
    else
      puts "Not Authorized".red
    end
    @exit_status = false
  rescue VMC::Client::TargetError, VMC::Client::NotFound, VMC::Client::BadTarget  => e
    puts e.message.red
    @exit_status = false
  rescue VMC::Client::HTTPException => e
    puts e.message.red
    @exit_status = false
  rescue VMC::Cli::GracefulExit => e
    # Redirected commands end up generating this exception (kind of goto)
  rescue VMC::Cli::CliExit => e
    puts e.message.red
    @exit_status = false
  rescue VMC::Cli::CliError => e
    say("Error #{e.error_code}: #{e.message}".red)
    @exit_status = false
  rescue SystemExit => e
    @exit_status = e.success?
  rescue SyntaxError => e
    puts e.message.red
    puts e.backtrace
    @exit_status = false
  rescue Interrupt => e
    say("\nInterrupted".red)
    @exit_status = false
  rescue Exception => e
    puts e.message.red
    puts e.backtrace
    @exit_status = false
  ensure
    say("\n")
    @exit_status == true if @exit_status.nil?
    if @options[:verbose]
      if @exit_status
        puts "[#{@namespace}:#{@action}] SUCCEEDED".green
      else
        puts "[#{@namespace}:#{@action}] FAILED".red
      end
      say("\n")
    end
    exit(@exit_status)
  end

end
