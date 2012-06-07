require "vmc/cli/command"
require "vmc/detect"

module VMC
  class App < Command
    MEM_CHOICES = ["64M", "128M", "256M", "512M"]

    # TODO: don't hardcode; bring in from remote
    MEM_DEFAULTS_FRAMEWORK = {
      "rails3" => "256M",
      "spring" => "512M",
      "grails" => "512M",
      "lift" => "512M",
      "java_web" => "512M",
      "standalone" => "64M",
      "sinatra" => "128M",
      "node" => "64M",
      "php" => "128M",
      "otp_rebar" => "64M",
      "wsgi" => "64M",
      "django" => "128M",
      "dotNet" => "128M",
      "rack" => "128M",
      "play" => "256M"
    }

    MEM_DEFAULTS_RUNTIME = {
      "java7" => "512M",
      "java" => "512M",
      "php" => "128M",
      "ruby" => "128M",
      "ruby19" => "128M"
    }


    desc "push [NAME]", "Push an application, syncing changes if it exists"
    group :apps, :manage
    flag(:name) { ask("Name") }
    flag(:path)
    flag(:url) { |default|
      ask("URL", :default => default)
    }
    flag(:memory) { |framework, runtime|
      ask("Memory Limit",
          :choices => MEM_CHOICES,
          :default =>
            MEM_DEFAULTS_RUNTIME[runtime] ||
              MEM_DEFAULTS_FRAMEWORK[framework] ||
              "64M")
    }
    flag(:instances) {
      ask("Instances", :default => 1)
    }
    flag(:framework) { |choices, default|
      opts = {:choices => choices}
      opts[:default] = default if default

      ask("Framework", opts)
    }
    flag(:runtime) { |choices|
      ask("Runtime", :choices => choices)
    }
    flag(:command) {
      ask("Startup command")
    }
    flag(:start, :default => true)
    flag(:restart, :default => true)
    flag(:create_services, :type => :boolean) {
      ask "Create services for application?", :default => false
    }
    flag(:bind_services, :type => :boolean) {
      ask "Bind other services to application?", :default => false
    }
    def push(name = nil)
      path = File.expand_path(input(:path) || ".")

      name ||= input(:name)

      detector = Detector.new(client, path)
      frameworks = detector.all_frameworks
      detected, default = detector.frameworks

      app = client.app(name)

      if app.exists?
        upload_app(app, path)
        restart(app.name) if input(:restart)
        return
      end

      app.total_instances = input(:instances)

      if detected.empty?
        framework = input(:framework, frameworks.keys.sort, nil)
      else
        framework = input(:framework, detected.keys.sort + ["other"], default)
        if framework == "other"
          forget(:framework)
          framework = input(:framework, frameworks.keys.sort, nil)
        end
      end

      framework_runtimes =
        frameworks[framework]["runtimes"].collect { |k| k["name"] }

      runtime = input(:runtime, framework_runtimes.sort)

      app.framework = framework
      app.runtime = runtime

      if framework == "standalone"
        app.command = input(:command)

        if (url = input(:url, "none")) != "none"
          app.urls = [url]
        else
          app.urls = []
        end
      else
        domain = client.target.sub(/^https?:\/\/api\.(.+)\/?/, '\1')
        app.urls = [input(:url, "#{name}.#{domain}")]
      end

      app.memory = megabytes(input(:memory, framework, runtime))

      bindings = []
      if input(:create_services) && !force?
        services = client.system_services

        while true
          vendor = ask "What kind?", :choices => services.keys.sort
          meta = services[vendor]

          if meta[:versions].size == 1
            version = meta[:versions].first
          else
            version = ask "Which version?",
              :choices => meta[:versions].sort.reverse
          end

          random = sprintf("%x", rand(1000000))
          service_name = ask "Service name?", :default => "#{vendor}-#{random}"

          service = client.service(service_name)
          service.type = meta[:type]
          service.vendor = meta[:vendor]
          service.version = version
          service.tier = "free"

          with_progress("Creating service #{c(service_name, :name)}") do
            service.create!
          end

          bindings << service_name

          break unless ask "Create another service?", :default => false
        end
      end

      if input(:bind_services) && !force?
        services = client.services.collect(&:name)

        while true
          choices = services - bindings
          break if choices.empty?

          bindings << ask("Bind which service?", :choices => choices.sort)

          unless bindings.size < services.size &&
                  ask("Bind another service?", :default => false)
            break
          end
        end
      end

      app.services = bindings

      with_progress("Creating #{c(name, :name)}") do
        app.create!
      end

      begin
        upload_app(app, path)
      rescue
        err "Upload failed. Try again with 'vmc push'."
        raise
      end

      start(name) if input(:start)
    end

    desc "start APPS...", "Start an application"
    group :apps, :manage
    flag :name
    flag :debug_mode, :aliases => "-d"
    def start(*names)
      if name = passed_value(:name)
        names = [name]
      end

      fail "No applications given." if names.empty?

      names.each do |name|
        app = client.app(name)

        fail "Unknown application." unless app.exists?

        switch_mode(app, input(:debug_mode))

        with_progress("Starting #{c(name, :name)}") do |s|
          if app.started?
            s.skip do
              err "Already started."
            end
          end

          app.start!
        end

        check_application(app)

        if app.debug_mode && !simple_output?
          puts ""
          instances(name)
        end
      end
    end

    desc "stop APPS...", "Stop an application"
    group :apps, :manage
    flag :name
    def stop(*names)
      if name = passed_value(:name)
        names = [name]
      end

      fail "No applications given." if names.empty?

      names.each do |name|
        with_progress("Stopping #{c(name, :name)}") do |s|
          app = client.app(name)

          unless app.exists?
            s.fail do
              err "Unknown application."
            end
          end

          if app.stopped?
            s.skip do
              err "Application is not running."
            end
          end

          app.stop!
        end
      end
    end

    desc "restart APPS...", "Stop and start an application"
    group :apps, :manage
    flag :name
    flag :debug_mode, :aliases => "-d"
    def restart(*names)
      stop(*names)
      start(*names)
    end

    desc "delete APPS...", "Delete an application"
    group :apps, :manage
    flag :name
    flag(:really) { |name, color|
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    flag(:name) { |names|
      ask("Delete which application?", :choices => names)
    }
    flag(:orphaned, :aliases => "-o", :type => :boolean,
          :desc => "Delete orphaned instances")
    flag(:all, :default => false)
    def delete(*names)
      if input(:all)
        return unless input(:really, "ALL APPS", :bad)

        apps = client.apps

        orphaned = find_orphaned_services(apps)

        apps.each do |a|
          with_progress("Deleting #{c(a.name, :name)}") do
            a.delete!
          end
        end

        delete_orphaned_services(orphaned)

        return
      end

      apps = client.apps

      if names.empty?
        fail "No applications." if apps.empty?

        names = [input(:name, apps.collect(&:name).sort)]
      end

      to_delete = names.collect { |n| apps.find { |a| a.name == n } }
      orphaned = find_orphaned_services(to_delete)

      to_delete.each do |app|
        really = input(:really, app.name, :name)

        forget(:really)

        next unless really

        with_progress("Deleting #{c(app.name, :name)}") do
          app.delete!
        end
      end

      delete_orphaned_services(orphaned)
    end

    desc "instances APPS...", "List an app's instances"
    group :apps, :info, :hidden => true
    flag :name
    def instances(*names)
      if name = passed_value(:name)
        names = [name]
      end

      fail "No applications given." if names.empty?

      names.each do |name|
        instances =
          with_progress("Getting instances for #{c(name, :name)}") do
            client.app(name).instances
          end

        instances.each do |i|
          if simple_output?
            puts i.index
          else
            puts ""
            display_instance(i)
          end
        end
      end
    end

    desc "scale APP", "Update the instances/memory limit for an application"
    group :apps, :info, :hidden => true
    flag :name
    flag(:instances, :type => :numeric) { |default|
      ask("Instances", :default => default)
    }
    flag(:memory) { |default|
      ask("Memory Limit",
          :default => human_size(default * 1024 * 1024, 0),
          :choices => MEM_CHOICES)
    }
    def scale(name = nil)
      name ||= input(:name)

      app = client.app(name)

      instances = passed_value(:instances)
      memory = passed_value(:memory)

      unless instances || memory
        instances = input(:instances, app.total_instances)
        memory = input(:memory, app.memory)
      end

      with_progress("Scaling #{c(name, :name)}") do
        app.total_instances = instances.to_i if instances
        app.memory = megabytes(memory) if memory
        app.update!
      end
    end

    desc "logs APP", "Print out an app's logs"
    group :apps, :info, :hidden => true
    flag :name
    flag(:instance, :type => :numeric, :default => 0)
    flag(:all, :default => false)
    def logs(name = nil)
      name ||= input(:name)

      app = client.app(name)
      fail "Unknown application." unless app.exists?

      instances =
        if input(:all)
          app.instances
        else
          app.instances.select { |i| i.index == input(:instance) }
        end

      if instances.empty?
        if input(:all)
          fail "No instances found."
        else
          fail "Instance #{name} \##{input(:instance)} not found."
        end
      end

      instances.each do |i|
        logs =
          with_progress(
            "Getting logs for " +
              c(name, :name) + " " +
              c("\##{i.index}", :instance)) do
            i.files("logs")
          end

        puts "" unless simple_output?

        logs.each do |log|
          body =
            with_progress("Reading " + b(log.join("/"))) do
              i.file(*log)
            end

          puts body
          puts "" unless body.empty?
        end
      end
    end

    desc "file APP [PATH]", "Print out an app's file contents"
    group :apps, :info, :hidden => true
    flag :name
    def file(name = nil, path = "/")
      name ||= input(:name)

      file =
        with_progress("Getting file contents") do
          client.app(name).file(*path.split("/"))
        end

      puts "" unless simple_output?

      print file
    end

    desc "files APP [PATH]", "Examine an app's files"
    group :apps, :info, :hidden => true
    flag :name
    def files(name = nil, path = "/")
      name ||= input(:name)

      files =
        with_progress("Getting file listing") do
          client.app(name).files(*path.split("/"))
        end

      puts "" unless simple_output?
      files.each do |file|
        puts file.join("/")
      end
    end

    desc "health ...APPS", "Get application health"
    group :apps, :info, :hidden => true
    flag :name
    def health(*names)
      if name = passed_value(:name)
        names = [name]
      end

      apps =
        with_progress("Getting application health") do
          names.collect do |n|
            [n, app_status(client.app(n))]
          end
        end

      apps.each do |name, status|
        unless simple_output?
          puts ""
          print "#{c(name, :name)}: "
        end

        puts status
      end
    end

    desc "stats APP", "Display application instance status"
    group :apps, :info, :hidden => true
    flag :name
    def stats(name = nil)
      name ||= input(:name)

      stats =
        with_progress("Getting stats") do
          client.app(name).stats
        end

      stats.sort_by { |k, _| k }.each do |idx, info|
        puts ""

        if info["state"] == "DOWN"
          puts "Instance #{c("\##{idx}", :instance)} is down."
          next
        end

        stats = info["stats"]
        usage = stats["usage"]
        puts "instance #{c("\##{idx}", :instance)}:"
        print "  cpu: #{percentage(usage["cpu"])} of"
        puts " #{b(stats["cores"])} cores"
        puts "  memory: #{usage(usage["mem"] * 1024, stats["mem_quota"])}"
        puts "  disk: #{usage(usage["disk"], stats["disk_quota"])}"
      end
    end

    desc "update", "DEPRECATED", :hide => true
    def update(*args)
      fail "The 'update' command is no longer used; use 'push' instead."
    end

    class URL < Command
      desc "map APP URL", "Add a URL mapping for an app"
      group :apps, :info, :hidden => true
      def map(name, url)
        simple = url.sub(/^https?:\/\/(.*)\/?/i, '\1')

        with_progress("Updating #{c(name, :name)}") do
          app = client.app(name)
          app.urls << simple
          app.update!
        end
      end

      desc "unmap APP URL", "Remove a URL mapping from an app"
      group :apps, :info, :hidden => true
      def unmap(name, url)
        simple = url.sub(/^https?:\/\/(.*)\/?/i, '\1')

        app = client.app(name)
        fail "Unknown application." unless app.exists?

        with_progress("Updating #{c(name, :name)}") do |s|
          unless app.urls.delete(simple)
            s.fail do
              err "URL #{url} is not mapped to this application."
              return
            end
          end

          app.update!
        end
      end
    end

    desc "url SUBCOMMAND ...ARGS", "Manage application URL bindings"
    subcommand "url", URL

    class Env < Command
      VALID_NAME = /^[a-zA-Za-z_][[:alnum:]_]*$/

      desc "set APP [NAME] [VALUE]", "Set an environment variable"
      group :apps, :info, :hidden => true
      def set(appname, name, value)
        unless name =~ VALID_NAME
          fail "Invalid variable name; must match #{VALID_NAME.inspect}"
        end

        app = client.app(appname)
        fail "Unknown application." unless app.exists?

        with_progress("Updating #{c(app.name, :name)}") do
          app.update!("env" =>
                        app.env.reject { |v|
                          v.start_with?("#{name}=")
                        }.push("#{name}=#{value}"))
        end
      end

      desc "unset APP [NAME]", "Remove an environment variable"
      group :apps, :info, :hidden => true
      def unset(appname, name)
        app = client.app(appname)
        fail "Unknown application." unless app.exists?

        with_progress("Updating #{c(app.name, :name)}") do
          app.update!("env" =>
                        app.env.reject { |v|
                          v.start_with?("#{name}=")
                        })
        end
      end

      desc "list APP", "Show all environment variables set for an app"
      group :apps, :info, :hidden => true
      def list(appname)
        vars =
          with_progress("Getting variables") do |s|
            app = client.app(appname)

            unless app.exists?
              s.fail do
                err "Unknown application."
                return
              end
            end

            app.env
          end

        puts "" unless simple_output?

        vars.each do |pair|
          name, val = pair.split("=", 2)
          puts "#{c(name, :name)}: #{val}"
        end
      end
    end

    desc "env SUBCOMMAND ...ARGS", "Manage application environment variables"
    subcommand "env", Env

    private

    def upload_app(app, path)
      with_progress("Uploading #{c(app.name, :name)}") do
        app.upload(path)
      end
    end

    # set app debug mode, ensuring it's valid, and shutting it down
    def switch_mode(app, mode)
      mode = nil if mode == "none"
      mode = "run" if mode == "debug_mode" # no value given

      return false if app.debug_mode == mode

      if mode.nil?
        with_progress("Removing debug mode") do
          app.debug_mode = nil
          app.stop! if app.started?
        end

        return true
      end

      with_progress("Switching mode to #{c(mode, :name)}") do |s|
        runtimes = client.system_runtimes
        modes = runtimes[app.runtime]["debug_modes"] || []
        if modes.include?(mode)
          app.debug_mode = mode
          app.stop! if app.started?
        else
          fail "Unknown mode '#{mode}'; available: #{modes.join ", "}"
        end
      end
    end

    APP_CHECK_LIMIT = 60

    def check_application(app)
      with_progress("Checking #{c(app.name, :name)}") do |s|
        if app.debug_mode == "suspend"
          s.skip do
            puts "Application is in suspended debugging mode."
            puts "It will wait for you to attach to it before starting."
          end
        end

        seconds = 0
        until app.healthy?
          sleep 1
          seconds += 1
          if seconds == APP_CHECK_LIMIT
            s.give_up do
              err "Application failed to start."
              # TODO: print logs
            end
          end
        end
      end
    end

    # choose the right color for app/instance state
    def state_color(s)
      case s
      when "STARTING"
        :neutral
      when "STARTED", "RUNNING"
        :good
      when "DOWN"
        :bad
      when "FLAPPING"
        :error
      when "N/A"
        :unknown
      else
        :warning
      end
    end

    def app_status(a)
      health = a.health

      if a.debug_mode == "suspend" && health == "0%"
        c("suspended", :neutral)
      else
        c(health.downcase, state_color(health))
      end
    end

    def display_instance(i)
      print "instance #{c("\##{i.index}", :instance)}: "
      puts "#{b(c(i.state.downcase, state_color(i.state)))} "

      puts "  started: #{c(i.since.strftime("%F %r"), :cyan)}"

      if d = i.debugger
        puts "  debugger: port #{b(d[:port])} at #{b(d[:ip])}"
      end

      if c = i.console
        puts "  console: port #{b(c[:port])} at #{b(c[:ip])}"
      end
    end

    def find_orphaned_services(apps)
      orphaned = []

      apps.each do |a|
        a.services.each do |s|
          if apps.none? { |x| x != a && x.services.include?(s) }
            orphaned << s
          end
        end
      end

      orphaned
    end

    def delete_orphaned_services(names)
      return if names.empty?

      puts "" unless simple_output?

      names.select { |s|
        input(:orphaned) ||
          ask("Delete orphaned service #{c(s, :name)}?", :default => false)
      }.each do |s|
        with_progress("Deleting service #{c(s, :name)}") do
          client.service(s).delete!
        end
      end
    end
  end
end
