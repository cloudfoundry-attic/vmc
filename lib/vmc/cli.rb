require "vmc/cli/command"
require "vmc/cli/app"
require "vmc/cli/service"
require "vmc/cli/user"

module VMC
  class CLI < App # subclass App since we operate on Apps by default
    class_option :proxy, :aliases => "-u", :desc => "Proxy user"

    class_option :verbose,
      :type => :boolean, :aliases => "-v", :desc => "Verbose"

    class_option :force,
      :type => :boolean, :aliases => "-f", :desc => "Force (no interaction)"

    class_option :simple_output,
      :type => :boolean, :desc => "Simplified output format."

    class_option :script, :type => :boolean, :aliases => "-s",
      :desc => "--simple-output and --force"

    class_option :color, :type => :boolean, :desc => "Colored output"

    desc "service SUBCOMMAND ...ARGS", "Manage your services"
    subcommand "service", Service

    desc "user SUBCOMMAND ...ARGS", "User management"
    subcommand "user", User

    desc "info", "Display information on the current target, user, et."
    flag(:runtimes)
    flag(:services)
    def info
      info =
        with_progress("Getting target information") do
          client.info
        end

      if input(:runtimes)
        runtimes = {}
        info["frameworks"].each do |_, f|
          f["runtimes"].each do |r|
            runtimes[r["name"]] = r
          end
        end

        runtimes = runtimes.values.sort_by { |x| x["name"] }

        if simple_output?
          runtimes.each do |r|
            puts r["name"]
          end
          return
        end

        runtimes.each do |r|
          puts ""
          puts "#{c(r["name"], :blue)}:"
          puts "  version: #{b(r["version"])}"
          puts "  description: #{b(r["description"])}"
        end

        return
      end

      if input(:services)
        services = {}
        client.system_services.each do |_, svcs|
          svcs.each do |name, versions|
            services[name] = versions.values
          end
        end

        if simple_output?
          services.each do |name, _|
            puts name
          end

          return
        end

        services.each do |name, versions|
          puts ""
          puts "#{c(name, :blue)}:"
          puts "  versions: #{versions.collect { |v| v["version"] }.join ", "}"
          puts "  description: #{versions[0]["description"]}"
          puts "  type: #{versions[0]["type"]}"
        end

        return
      end

      puts ""

      puts info["description"]
      puts ""
      puts "target: #{b(client.target)}"
      puts "  version: #{info["version"]}"
      puts "  support: #{info["support"]}"

      if info["user"]
        puts ""
        puts "user: #{b(info["user"])}"
        puts "  usage:"

        limits = info["limits"]
        info["usage"].each do |k, v|
          m = limits[k]
          if k == "memory"
            puts "    #{k}: #{usage(v * 1024 * 1024, m * 1024 * 1024)}"
          else
            puts "    #{k}: #{b(v)} of #{b(m)} limit"
          end
        end
      end
    end

    desc "target [URL]", "Set or display the current target cloud"
    def target(url = nil)
      if url.nil?
        display_target
        return
      end

      target = sane_target_url(url)
      display = c(target.sub(/https?:\/\//, ""), :blue)
      with_progress("Setting target to #{display}") do
        unless force?
          # check that the target is valid
          CFoundry::Client.new(target).info
        end

        set_target(target)
      end
    end

    desc "login [EMAIL]", "Authenticate with the target"
    flag(:email) {
      ask("Email")
    }
    flag(:password)
    # TODO: implement new authentication scheme
    def login(email = nil)
      unless simple_output?
        display_target
        puts ""
      end

      email ||= input(:email)
      password = input(:password)

      authenticated = false
      failed = false
      until authenticated
        unless force?
          if failed || !password
            password = ask("Password", :echo => "*", :forget => true)
          end
        end

        with_progress("Authenticating") do |s|
          begin
            save_token(client.login(email, password))
            authenticated = true
          rescue CFoundry::Denied
            return if force?

            s.fail do
              failed = true
            end
          end
        end
      end
    ensure
      $exit_status = 1 if not authenticated
    end

    desc "logout", "Log out from the target"
    def logout
      with_progress("Logging out") do
        remove_token
      end
    end

    desc "register [EMAIL]", "Create a user and log in"
    flag(:email) {
      ask("Email")
    }
    flag(:password) {
      ask("Password", :echo => "*", :forget => true)
    }
    flag(:no_login, :type => :boolean)
    def register(email = nil)
      unless simple_output?
        puts "Target: #{c(client_target, :blue)}"
        puts ""
      end

      email ||= input(:email)
      password = input(:password)

      with_progress("Creating user") do
        client.register(email, password)
      end

      unless input(:skip_login)
        with_progress("Logging in") do
          save_token(client.login(email, password))
        end
      end
    end

    desc "services", "List your services"
    def services
      services =
        with_progress("Getting services") do
          client.services
        end

      puts "" unless simple_output?

      if services.empty? and !simple_output?
        puts "No services."
      end

      services.each do |s|
        display_service(s)
      end
    end

    desc "users", "List all users"
    def users
      users =
        with_progress("Getting users") do
          client.users
        end

      users.each do |u|
        display_user(u)
      end
    end

    private

    def display_service(s)
      if simple_output?
        puts s.name
      else
        puts "#{c(s.name, :blue)}: #{s.vendor} v#{s.version}"
      end
    end

    def display_user(u)
      if simple_output?
        puts u.email
      else
        puts ""
        puts "#{c(u.email, :blue)}:"
        puts "  admin?: #{c(u.admin?, u.admin? ? :green : :red)}"
      end
    end

    def display_target
      if simple_output?
        puts client.target
      else
        puts "Target: #{c(client.target, :blue)}"
      end
    end
  end
end
