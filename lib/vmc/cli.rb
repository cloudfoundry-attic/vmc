require "vmc/cli/command"

VMC::Command.groups(
  [:start, "Getting Started"],
  [:apps, "Applications",
    [:manage, "Management"],
    [:info, "Information"]],
  [:services, "Services",
    [:manage, "Management"]],
  [:admin, "Administration",
    [:user, "User Management"]])

require "vmc/cli/app"
require "vmc/cli/service"
require "vmc/cli/user"

module VMC
  class CLI < App # subclass App since we operate on Apps by default
    desc "service SUBCOMMAND ...ARGS", "Service management"
    subcommand "service", Service

    desc "user SUBCOMMAND ...ARGS", "User management"
    subcommand "user", User

    desc "info", "Display information on the current target, user, etc."
    group :start
    flag :runtimes, :default => false
    flag :services, :default => false
    flag :frameworks, :default => false
    def info
      info =
        with_progress("Getting target information") do
          client.info
        end

      authorized = !!info["frameworks"]

      if input(:runtimes)
        raise NotAuthorized unless authorized

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
        raise NotAuthorized unless authorized

        services = client.system_services

        if simple_output?
          services.each do |name, _|
            puts name
          end

          return
        end

        services.each do |name, meta|
          puts ""
          puts "#{c(name, :blue)}:"
          puts "  versions: #{meta[:versions].join ", "}"
          puts "  description: #{meta[:description]}"
          puts "  type: #{meta[:type]}"
        end

        return
      end

      if input(:frameworks)
        raise NotAuthorized unless authorized

        puts "" unless simple_output?

        info["frameworks"].each do |name, _|
          puts name
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
    group :start
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
    group :start
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
    group :start
    def logout
      with_progress("Logging out") do
        remove_token
      end
    end

    desc "register [EMAIL]", "Create a user and log in"
    group :start, :hidden => true
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

    desc "apps", "List your applications"
    group :apps
    def apps
      apps =
        with_progress("Getting applications") do
          client.apps
        end

      if apps.empty? and !simple_output?
        puts ""
        puts "No applications."
        return
      end

      apps.each.with_index do |a, num|
        display_app(a)
      end
    end

    desc "services", "List your services"
    group :services
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
    group :admin, :hidden => true
    def users
      users =
        with_progress("Getting users") do
          client.users
        end

      users.each do |u|
        display_user(u)
      end
    end

    desc "help [COMMAND]", "usage instructions"
    flag :all, :default => false
    group :start
    def help(task = nil)
      if options[:version]
        puts "vmc #{VERSION}"
        return
      end

      if task
        self.class.task_help(@shell, task)
      else
        unless input(:all)
          puts "Showing basic command set. Pass --all to list all commands."
          puts ""
        end

        self.class.print_help_groups(input(:all))
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
