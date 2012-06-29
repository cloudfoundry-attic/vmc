require "vmc/cli"

module VMC
  class Start < CLI
    desc "Display information on the current target, user, etc."
    group :start
    input :runtimes, :type => :boolean
    input :services, :type => :boolean
    input :frameworks, :type => :boolean
    def info(input)
      info =
        with_progress("Getting target information") do
          client.info
        end

      authorized = !!info["frameworks"]

      if input[:runtimes]
        raise NotAuthorized unless authorized

        runtimes = {}
        info["frameworks"].each do |_, f|
          f["runtimes"].each do |r|
            runtimes[r["name"]] = r
          end
        end

        runtimes = runtimes.values.sort_by { |x| x["name"] }

        if quiet?
          runtimes.each do |r|
            puts r["name"]
          end
          return
        end

        runtimes.each do |r|
          puts ""
          puts "#{c(r["name"], :name)}:"
          puts "  version: #{b(r["version"])}"
          puts "  description: #{b(r["description"])}"
        end

        return
      end

      if input[:services]
        raise NotAuthorized unless authorized

        services = client.system_services

        if quiet?
          services.each do |name, _|
            puts name
          end

          return
        end

        services.each do |name, meta|
          puts ""
          puts "#{c(name, :name)}:"
          puts "  versions: #{meta[:versions].join ", "}"
          puts "  description: #{meta[:description]}"
          puts "  type: #{meta[:type]}"
        end

        return
      end

      if input[:frameworks]
        raise NotAuthorized unless authorized

        puts "" unless quiet?

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


    desc "Set or display the current target cloud"
    group :start
    input :url, :argument => :optional
    def target(input)
      if !input.given?(:url)
        display_target
        return
      end

      target = sane_target_url(input[:url])
      display = c(target.sub(/https?:\/\//, ""), :name)
      with_progress("Setting target to #{display}") do
        unless force?
          # check that the target is valid
          CFoundry::Client.new(target).info
        end

        set_target(target)
      end
    end


    desc "List known targets."
    group :start, :hidden => true
    def targets(input)
      tokens.each do |target, auth|
        puts target
      end
    end


    desc "Authenticate with the target"
    group :start
    input(:email, :argument => true) {
      ask("Email")
    }
    input(:password)
    # TODO: implement new authentication scheme
    def login(input)
      unless quiet?
        display_target
        puts ""
      end

      email = input[:email]
      password = input[:password]

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
      exit_status 1 if not authenticated
    end


    desc "Log out from the target"
    group :start
    def logout(input)
      with_progress("Logging out") do
        remove_token
      end
    end


    desc "Create a user and log in"
    group :start, :hidden => true
    input(:email, :argument => true) {
      ask("Email")
    }
    input(:password) {
      ask("Password", :echo => "*", :forget => true)
    }
    input(:verify_password) {
      ask("Confirm Password", :echo => "*", :forget => true)
    }
    input(:no_login, :type => :boolean)
    def register(input)
      unless quiet?
        puts "Target: #{c(client_target, :name)}"
        puts ""
      end

      email = input[:email]
      password = input[:password]

      if !force? && password != input[:verify_password]
        fail "Passwords do not match."
      end

      with_progress("Creating user") do
        client.register(email, password)
      end

      unless input[:skip_login]
        with_progress("Logging in") do
          save_token(client.login(email, password))
        end
      end
    end


    desc "Show color configuration"
    group :start, :hidden => true
    def colors(input)
      user_colors.each do |n, c|
        puts "#{n}: #{c(c.to_s, n)}"
      end
    end

    private

    def display_target
      if quiet?
        puts client.target
      else
        puts "Target: #{c(client.target, :name)}"
      end
    end
  end
end
