require "vmc/cli"
require "vmc/detect"

module VMC
  class App < CLI
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


    def self.find_by_name(what)
      proc { |name, choices|
        choices.find { |c| c.name == name } ||
          fail("Unknown #{what} '#{name}'")
      }
    end


    desc "List your applications"
    group :apps
    input :name, :desc => "Filter by name regexp"
    input :runtime, :desc => "Filter by runtime regexp"
    input :framework, :desc => "Filter by framework regexp"
    input :url, :desc => "Filter by url regexp"
    def apps(input)
      if v2?
        space = client.current_space
        apps =
          with_progress("Getting applications in #{c(space.name, :name)}") do
            space.apps
          end
      else
        apps =
          with_progress("Getting applications") do
            client.apps
          end
      end

      if apps.empty? and !quiet?
        puts ""
        puts "No applications."
        return
      end

      apps.each.with_index do |a, num|
        display_app(a) if app_matches(a, input)
      end
    end


    desc "Push an application, syncing changes if it exists"
    group :apps, :manage
    input(:name, :argument => true, :desc => "Application name") {
      ask("Name")
    }
    input :path, :desc => "Path containing the application"
    input(:url, :desc => "URL bound to app") { |default|
      ask("URL", :default => default)
    }
    input(:memory, :desc => "Memory limit") { |framework, runtime|
      ask("Memory Limit",
          :choices => MEM_CHOICES,
          :default =>
            MEM_DEFAULTS_RUNTIME[runtime] ||
              MEM_DEFAULTS_FRAMEWORK[framework] ||
              "64M")
    }
    input(:instances, :type => :integer,
          :desc => "Number of instances to run") {
      ask("Instances", :default => 1)
    }
    input(:framework, :desc => "Framework to use",
          :from_given => find_by_name("framework")) { |choices, default, other|
      choices = choices.sort_by(&:name)
      choices << other if other

      opts = {
        :choices => choices,
        :display => proc { |f|
          if f == other
            "other"
          else
            f.name
          end
        }
      }

      opts[:default] = default if default

      ask("Framework", opts)
    }
    input(:runtime, :desc => "Runtime to run it with",
          :from_given => find_by_name("runtime")) { |choices|
      ask("Runtime", :choices => choices, :display => proc(&:name))
    }
    input(:command, :desc => "Startup command for standalone app") {
      ask("Startup command")
    }
    input :start, :type => :boolean, :default => true,
      :desc => "Start app after pushing?"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    input(:create_services, :type => :boolean,
          :desc => "Interactively create services?") {
      ask "Create services for application?", :default => false
    }
    input(:bind_services, :type => :boolean,
          :desc => "Interactively bind services?") {
      ask "Bind other services to application?", :default => false
    }
    def push(input)
      path = File.expand_path(input[:path] || ".")

      name = input[:name] if input[:name]

      if exists = client.app_by_name(name)
        upload_app(exists, path)
        invoke :restart, :name => exists.name if input[:restart]
        return
      end

      detector = Detector.new(client, path)
      frameworks = detector.all_frameworks
      detected, default = detector.frameworks

      app = client.app
      app.name = name
      app.space = client.current_space if v2?
      app.total_instances = input[:instances]

      if detected.empty?
        framework = input[:framework, frameworks, nil, false]
      else
        detected_names = detected.collect(&:name).sort
        framework = input[:framework, detected, default, true]

        if framework == :other
          input.forget(:framework)
          framework = input[:framework, frameworks, nil, false]
        end
      end

      runtimes = v2? ? client.runtimes : framework.runtimes
      runtime = input[:runtime, runtimes]

      fail "Invalid framework '#{input[:framework]}'" unless framework
      fail "Invalid runtime '#{input[:runtime]}'" unless runtime

      app.framework = framework
      app.runtime = runtime

      if framework == "standalone"
        app.command = input[:command]

        if (url = input[:url, "none"]) != "none"
          app.urls = [url]
        else
          app.urls = []
        end
      else
        domain = client.target.sub(/^https?:\/\/[^\.]+\.(.+)\/?/, '\1')
        app.urls = [input[:url, "#{name}.#{domain}"]]
      end

      app.memory = megabytes(input[:memory, framework, runtime])

      bindings = []
      if !v2? && input[:create_services] && !force?
        services = client.services

        while true
          instance = invoke :create_service

          bindings << instance.name

          break unless ask "Create another service?", :default => false
        end
      end

      if !v2? && input[:bind_services] && !force?
        services = client.service_instances.collect(&:name)

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

      app = filter(:push_app, app)

      with_progress("Creating #{c(name, :name)}") do
        app.create!
      end

      begin
        upload_app(app, path)
      rescue
        err "Upload failed. Try again with 'vmc push'."
        raise
      end

      invoke :start, :name => app.name if input[:start]
    end


    desc "Start an application"
    group :apps, :manage
    input :names, :argument => :splat, :singular => :name,
      :desc => "Applications to start"
    input :debug_mode, :aliases => "-d",
      :desc => "Debug mode to start in"
    def start(input)
      names = input[:names]
      fail "No applications given." if names.empty?

      apps = client.apps

      names.each do |name|
        app = apps.find { |a| a.name == name }

        fail "Unknown application '#{name}'" unless app

        app = filter(:start_app, app)

        switch_mode(app, input[:debug_mode])

        with_progress("Starting #{c(name, :name)}") do |s|
          if app.started?
            s.skip do
              err "Already started."
            end
          end

          app.start!
        end

        # TODO: reenable for v2
        next if v2?

        check_application(app)

        if app.debug_mode && !quiet?
          puts ""
          instances(name)
        end
      end
    end


    desc "Stop an application"
    group :apps, :manage
    input :names, :argument => :splat, :singular => :name,
      :desc => "Applications to stop"
    def stop(input)
      names = input[:names]
      fail "No applications given." if names.empty?

      apps = client.apps

      names.each do |name|
        app = apps.find { |a| a.name == name }

        fail "Unknown application '#{name}'" unless app

        with_progress("Stopping #{c(name, :name)}") do |s|
          if app.stopped?
            s.skip do
              err "Application is not running."
            end
          end

          app.stop!
        end
      end
    end


    desc "Stop and start an application"
    group :apps, :manage
    input :names, :argument => :splat, :singular => :name,
      :desc => "Applications to stop"
    input :debug_mode, :aliases => "-d",
      :desc => "Debug mode to start in"
    def restart(input)
      invoke :stop, :names => input[:names]
      invoke :start, :names => input[:names],
        :debug_mode => input[:debug_mode]
    end


    desc "Delete an application"
    group :apps, :manage
    input(:really, :type => :boolean, :forget => true) { |name, color|
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    input(:apps, :argument => :splat, :singular => :app,
          :desc => "Applications to delete",
          :from_given => find_by_name("application")) { |apps|
      [ask("Delete which application?", :choices => apps.sort_by(&:name),
           :display => proc(&:name))]
    }
    input :orphaned, :aliases => "-o", :type => :boolean,
      :desc => "Delete orphaned instances"
    input :all, :default => false,
      :desc => "Delete all applications"
    def delete(input)
      if input[:all]
        return unless input[:really, "ALL APPS", :bad]

        apps = client.apps

        orphaned = find_orphaned_services(apps)

        apps.each do |a|
          with_progress("Deleting #{c(a.name, :name)}") do
            a.delete!
          end
        end

        delete_orphaned_services(orphaned, input[:orphaned])

        return
      end

      apps = client.apps
      fail "No applications." if apps.empty?

      to_delete = input[:apps, apps]

      deleted = []
      to_delete.each do |app|
        really = input[:really, app.name, :name]
        next unless really

        deleted << app

        with_progress("Deleting #{c(app.name, :name)}") do
          app.delete!
        end
      end

      unless deleted.empty?
        delete_orphaned_services(
          find_orphaned_services(deleted),
          input[:orphaned])
      end
    end


    desc "List an app's instances"
    group :apps, :info, :hidden => true
    input :names, :argument => :splat, :singular => :name,
      :desc => "Applications to list instances of"
    def instances(input)
      no_v2

      names = input[:names]
      fail "No applications given." if names.empty?

      names.each do |name|
        instances =
          with_progress("Getting instances for #{c(name, :name)}") do
            client.app_by_name(name).instances
          end

        instances.each do |i|
          if quiet?
            puts i.index
          else
            puts ""
            display_instance(i)
          end
        end
      end
    end


    desc "Update the instances/memory limit for an application"
    group :apps, :info, :hidden => true
    input :name, :argument => true, :desc => "Application to update"
    input(:instances, :type => :numeric,
          :desc => "Number of instances to run") { |default|
      ask("Instances", :default => default)
    }
    input(:memory, :desc => "Memory limit") { |default|
      ask("Memory Limit", :choices => MEM_CHOICES,
          :default => human_size(default * 1024 * 1024, 0))
    }
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def scale(input)
      name = input[:name]
      app = client.app_by_name(name)

      instances = input.given(:instances)
      memory = input.given(:memory)

      unless instances || memory
        instances = input[:instances, app.total_instances]
        memory = input[:memory, app.memory]
      end

      megs = megabytes(memory)

      memory_changed = megs != app.memory
      instances_changed = instances != app.total_instances

      return unless memory_changed || instances_changed

      with_progress("Scaling #{c(name, :name)}") do
        app.total_instances = instances.to_i if instances
        app.memory = megs if memory
        app.update!
      end

      if memory_changed && app.started? && input[:restart]
        invoke :restart, :name => name
      end
    end


    desc "Print out an app's logs"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to get the logs of"
    input :instance, :type => :numeric, :default => 0,
      :desc => "Instance of application to get the logs of"
    input :all, :default => false,
      :desc => "Get logs for every instance"
    def logs(input)
      no_v2

      name = input[:name]

      app = client.app_by_name(name)
      fail "Unknown application '#{name}'" unless app.exists?

      instances =
        if input[:all]
          app.instances
        else
          app.instances.select { |i| i.index == input[:instance] }
        end

      if instances.empty?
        if input[:all]
          fail "No instances found."
        else
          fail "Instance #{name} \##{input[:instance]} not found."
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

        puts "" unless quiet?

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


    desc "Print out an app's file contents"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to inspect the files of"
    input :path, :argument => true, :default => "/",
      :desc => "Path of file to read"
    def file(input)
      no_v2

      file =
        with_progress("Getting file contents") do
          client.app(input[:name]).file(*input[:path].split("/"))
        end

      puts "" unless quiet?

      print file
    end

    desc "Examine an app's files"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to inspect the files of"
    input :path, :argument => true, :default => "/",
      :desc => "Path of directory to list"
    def files(input)
      no_v2

      files =
        with_progress("Getting file listing") do
          client.app(input[:name]).files(*input[:path].split("/"))
        end

      puts "" unless quiet?
      files.each do |file|
        puts file.join("/")
      end
    end


    desc "Get application health"
    group :apps, :info, :hidden => true
    input :names, :argument => :splat, :singular => :name,
      :desc => "Application to check the status of"
    def health(input)
      # TODO: get all apps and filter

      apps =
        with_progress("Getting application health") do
          input[:names].collect do |n|
            [n, app_status(client.app_by_name(n))]
          end
        end

      apps.each do |name, status|
        unless quiet?
          puts ""
          print "#{c(name, :name)}: "
        end

        puts status
      end
    end


    desc "Display application instance status"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to get the stats for"
    def stats(input)
      no_v2

      stats =
        with_progress("Getting stats for #{c(input[:name], :name)}") do
          client.app_by_name(input[:name]).stats
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


    desc "Add a URL mapping for an app"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to add the URL to"
    input :url, :argument => true,
      :desc => "URL to route"
    def map(input)
      no_v2

      name = input[:name]
      simple = input[:url].sub(/^https?:\/\/(.*)\/?/i, '\1')

      with_progress("Updating #{c(name, :name)}") do
        app = client.app_by_name(name)
        app.urls << simple
        app.update!
      end
    end


    desc "Remove a URL mapping from an app"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to remove the URL from"
    input(:url, :argument => true, :desc => "URL to unmap") { |choices|
      ask("Which URL?", :choices => choices)
    }
    def unmap(input)
      no_v2

      name = input[:name]
      app = client.app_by_name(name)

      url = input[:url, app.urls]

      simple = url.sub(/^https?:\/\/(.*)\/?/i, '\1')

      fail "Unknown application '#{name}'" unless app.exists?

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


    desc "Show all environment variables set for an app"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to inspect the environment of"
    def env(input)
      appname = input[:name]

      vars =
        with_progress("Getting env for #{c(input[:name], :name)}") do |s|
          app = client.app_by_name(appname)

          unless app.exists?
            s.fail do
              err "Unknown application '#{appname}'"
              return
            end
          end

          app.env
        end

      puts "" unless quiet?

      vars.each do |pair|
        name, val = pair.split("=", 2)
        puts "#{c(name, :name)}: #{val}"
      end
    end


    VALID_ENV_VAR = /^[a-zA-Za-z_][[:alnum:]_]*$/

    desc "Set an environment variable"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to set the variable for"
    input :var, :argument => true,
      :desc => "Environment variable name"
    input :value, :argument => :optional,
      :desc => "Environment variable value"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def set_env(input)
      appname = input[:name]
      name = input[:var]

      if value = input[:value]
        name = input[:var]
      elsif name["="]
        name, value = name.split("=")
      end

      unless name =~ VALID_ENV_VAR
        fail "Invalid variable name; must match #{VALID_ENV_VAR.inspect}"
      end

      app = client.app_by_name(appname)
      fail "Unknown application '#{appname}'" unless app.exists?

      with_progress("Updating #{c(app.name, :name)}") do
        app.update!("env" =>
                      app.env.reject { |v|
                        v.start_with?("#{name}=")
                      }.push("#{name}=#{value}"))
      end

      if app.started? && input[:restart]
        invoke :restart, :name => app.name
      end
    end

    alias_command :set_env, :env_set
    alias_command :set_env, :add_env
    alias_command :set_env, :env_add


    desc "Remove an environment variable"
    group :apps, :info, :hidden => true
    input :name, :argument => true,
      :desc => "Application to remove the variable from"
    input :var, :argument => true,
      :desc => "Environment variable name"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def delete_env(input)
      appname = input[:name]
      name = input[:var]

      app = client.app_by_name(appname)
      fail "Unknown application '#{appname}'" unless app.exists?

      with_progress("Updating #{c(app.name, :name)}") do
        app.update!("env" =>
                      app.env.reject { |v|
                        v.start_with?("#{name}=")
                      })
      end

      if app.started? && input[:restart]
        invoke :restart, :name => app.name
      end
    end

    alias_command :delete_env, :env_del


    desc "DEPRECATED. Use 'push' instead."
    def update(input)
      fail "The 'update' command is no longer needed; use 'push' instead."
    end

    private

    def app_matches(a, options)
      if name = options[:name]
        return false if a.name !~ /#{name}/
      end

      if runtime = options[:runtime]
        return false if a.runtime.name !~ /#{runtime}/
      end

      if framework = options[:framework]
        return false if a.framework.name !~ /#{framework}/
      end

      if url = options[:url]
        return false if a.urls.none? { |u| u =~ /#{url}/ }
      end

      true
    end

    IS_UTF8 = !!(ENV["LC_ALL"] || ENV["LC_CTYPE"] || ENV["LANG"])["UTF-8"]

    def display_app(a)
      if quiet?
        puts a.name
        return
      end

      puts ""

      status = app_status(a)

      puts "#{c(a.name, :name)}: #{status}"

      puts "  platform: #{b(a.framework.name)} on #{b(a.runtime.name)}"

      print "  usage: #{b(human_size(a.memory * 1024 * 1024, 0))}"
      print " #{c(IS_UTF8 ? "\xc3\x97" : "x", :dim)} #{b(a.total_instances)}"
      print " instance#{a.total_instances == 1 ? "" : "s"}"
      puts ""

      unless a.urls.empty?
        puts "  urls: #{a.urls.collect { |u| b(u) }.join(", ")}"
      end

      unless a.services.empty?
        puts "  services: #{a.services.collect { |s| b(s) }.join(", ")}"
      end
    end

    def upload_app(app, path)
      if v2?
        fail "V2 API currently does not support uploading or starting apps."
      end

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
        runtime = client.runtimes.find { |r| r.name == app.runtime.name }
        modes = runtime.debug_modes

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

    def delete_orphaned_services(names, orphaned)
      return if names.empty?

      puts "" unless quiet?

      names.select { |s|
        orphaned ||
          ask("Delete orphaned service #{c(s, :name)}?", :default => false)
      }.each do |name|
        # TODO: splat
        invoke :delete_service, :name => name, :really => true
      end
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
