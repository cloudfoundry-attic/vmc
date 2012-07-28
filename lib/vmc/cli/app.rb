require "set"

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

    def self.by_name(what)
      proc { |name|
        client.send(:"#{what}_by_name", name) ||
          fail("Unknown #{what} '#{name}'")
      }
    end


    desc "List your applications"
    group :apps
    input :space, :desc => "Show apps in given space",
      :from_given => by_name("space")
    input :name, :desc => "Filter by name regexp"
    input :runtime, :desc => "Filter by runtime regexp"
    input :framework, :desc => "Filter by framework regexp"
    input :url, :desc => "Filter by url regexp"
    def apps(input)
      if space = input[:space] || client.current_space
        apps =
          with_progress("Getting applications in #{c(space.name, :name)}") do
            # depth of 2 for service binding instance names
            space.apps(2)
          end
      else
        apps =
          with_progress("Getting applications") do
            client.apps
          end
      end

      if apps.empty? and !quiet?
        line "No applications."
        return
      end

      line unless quiet?

      apps.reject! do |a|
        !app_matches(a, input)
      end

      spaced(apps) do |a|
        display_app(a)
      end
    end


    desc "Show app information"
    group :apps
    input :app, :argument => :required, :from_given => by_name("app"),
      :desc => "App to show"
    def app(input)
      display_app(input[:app])
    end

    desc "Push an application, syncing changes if it exists"
    group :apps, :manage
    input(:name, :argument => true, :desc => "Application name") {
      ask("Name")
    }
    input :path, :default => ".",
      :desc => "Path containing the application"
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
    input(:framework, :from_given => find_by_name("framework"),
          :desc => "Framework to use") { |choices, default, other|
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
      path = File.expand_path(input[:path])

      name = input[:name]

      if exists = client.app_by_name(name)
        upload_app(exists, path)
        invoke :restart, :app => exists if input[:restart]
        return
      end

      app = client.app
      app.name = name
      app.space = client.current_space if client.current_space
      app.total_instances = input[:instances]

      detector = Detector.new(client, path)
      frameworks = detector.all_frameworks
      detected, default = detector.frameworks

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

      app = filter(:create_app, app)

      with_progress("Creating #{c(app.name, :name)}") do
        app.create!
      end

      bindings = []

      if input[:create_services] && !force?
        while true
          invoke :create_service, :app => app
          break unless ask "Create another service?", :default => false
        end
      end

      if input[:bind_services] && !force?
        instances = client.service_instances

        while true
          invoke :bind_service, :app => app

          break if (instances - app.services).empty?

          break unless ask("Bind another service?", :default => false)
        end
      end

      app = filter(:push_app, app)

      begin
        upload_app(app, path)
      rescue
        err "Upload failed. Try again with 'vmc push'."
        raise
      end

      invoke :start, :app => app if input[:start]
    end


    desc "Start an application"
    group :apps, :manage
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    input :debug_mode, :aliases => "-d",
      :desc => "Debug mode to start in"
    def start(input)
      apps = input[:apps]
      fail "No applications given." if apps.empty?

      spaced(apps) do |app|
        app = filter(:start_app, app)

        switch_mode(app, input[:debug_mode])

        with_progress("Starting #{c(app.name, :name)}") do |s|
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
          line
          invoke :instances, :app => app
        end
      end
    end


    desc "Stop an application"
    group :apps, :manage
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    def stop(input)
      apps = input[:apps]
      fail "No applications given." if apps.empty?

      spaced(apps) do |app|
        with_progress("Stopping #{c(app.name, :name)}") do |s|
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
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    input :debug_mode, :aliases => "-d",
      :desc => "Debug mode to start in"
    def restart(input)
      invoke :stop, :apps => input[:apps]
      invoke :start, :apps => input[:apps],
        :debug_mode => input[:debug_mode]
    end


    desc "Delete an application"
    group :apps, :manage
    input(:apps, :argument => :splat, :singular => :app,
          :desc => "Applications to delete",
          :from_given => by_name("app")) {
      apps = client.apps
      fail "No applications." if apps.empty?

      [ask("Delete which application?", :choices => apps.sort_by(&:name),
           :display => proc(&:name))]
    }
    input(:really, :type => :boolean, :forget => true) { |name, color|
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    input :orphaned, :aliases => "-o", :type => :boolean,
      :desc => "Delete orphaned instances"
    input :all, :default => false,
      :desc => "Delete all applications"
    def delete(input)
      apps = client.apps

      if input[:all]
        return unless input[:really, "ALL APPS", :bad]

        to_delete = apps
        others = []
      else
        to_delete = input[:apps]
        others = apps - to_delete
      end

      orphaned = find_orphaned_services(to_delete, others)

      deleted = []
      spaced(to_delete) do |app|
        really = input[:all] || input[:really, app.name, :name]
        next unless really

        deleted << app

        with_progress("Deleting #{c(app.name, :name)}") do
          app.delete!
        end
      end

      delete_orphaned_services(orphaned, input[:orphaned])

      to_delete
    end


    desc "List an app's instances"
    group :apps, :info, :hidden => true
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    def instances(input)
      no_v2

      apps = input[:apps]
      fail "No applications given." if apps.empty?

      spaced(apps) do |app|
        instances =
          with_progress("Getting instances for #{c(app.name, :name)}") do
            app.instances
          end

        spaced(instances) do |i|
          if quiet?
            line i.index
          else
            line
            display_instance(i)
          end
        end
      end
    end


    desc "Update the instances/memory limit for an application"
    group :apps, :info, :hidden => true
    input :app, :argument => true, :desc => "Application to update",
      :from_given => by_name("app")
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
      app = input[:app]

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

      with_progress("Scaling #{c(app.name, :name)}") do
        app.total_instances = instances.to_i if instances
        app.memory = megs if memory
        app.update!
      end

      if memory_changed && app.started? && input[:restart]
        invoke :restart, :app => app
      end
    end


    desc "Print out an app's logs"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to get the logs of",
      :from_given => by_name("app")
    input :instance, :type => :numeric, :default => 0,
      :desc => "Instance of application to get the logs of"
    input :all, :default => false,
      :desc => "Get logs for every instance"
    def logs(input)
      no_v2

      app = input[:app]

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
          fail "Instance #{app.name} \##{input[:instance]} not found."
        end
      end

      spaced(instances) do |i|
        logs =
          with_progress(
              "Getting logs for #{c(app.name, :name)}" +
                c("\##{i.index}", :instance)) do
            i.files("logs")
          end

        line unless quiet?

        spaced(logs) do |log|
          body =
            with_progress("Reading " + b(log.join("/"))) do
              i.file(*log)
            end

          lines body
          line unless body.empty?
        end
      end
    end


    desc "Print out an app's file contents"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to inspect the files of",
      :from_given => by_name("app")
    input :path, :argument => true, :default => "/",
      :desc => "Path of file to read"
    def file(input)
      no_v2

      app = input[:app]

      file =
        with_progress("Getting file contents") do
          app.file(*input[:path].split("/"))
        end

      line unless quiet?

      print file
    end

    desc "Examine an app's files"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to inspect the files of",
      :from_given => by_name("app")
    input :path, :argument => true, :default => "/",
      :desc => "Path of directory to list"
    def files(input)
      no_v2

      app = input[:app]

      files =
        with_progress("Getting file listing") do
          app.files(*input[:path].split("/"))
        end

      line unless quiet?
      files.each do |file|
        line file.join("/")
      end
    end


    desc "Get application health"
    group :apps, :info, :hidden => true
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    def health(input)
      apps = input[:apps]
      fail "No applications given." if apps.empty?

      health =
        with_progress("Getting health status") do
          apps.collect { |a| [a, app_status(a)] }
        end

      line unless quiet?

      spaced(health) do |app, status|
        start_line "#{c(app.name, :name)}: " unless quiet?
        puts status
      end
    end


    desc "Display application instance status"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to get the stats for",
      :from_given => by_name("app")
    def stats(input)
      no_v2

      app = input[:app]

      stats =
        with_progress("Getting stats for #{c(app.name, :name)}") do
          app.stats
        end

      spaced(stats.sort_by(&:first)) do |idx, info|
        line

        if info[:state] == "DOWN"
          line "Instance #{c("\##{idx}", :instance)} is down."
          next
        end

        stats = info[:stats]
        usage = stats[:usage]
        line "instance #{c("\##{idx}", :instance)}:"

        indented do
          line "cpu: #{percentage(usage[:cpu])} of #{b(stats[:cores])} cores"
          line "memory: #{usage(usage[:mem] * 1024, stats[:mem_quota])}"
          line "disk: #{usage(usage[:disk], stats[:disk_quota])}"
        end
      end
    end


    desc "Add a URL mapping for an app"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to add the URL to",
      :from_given => by_name("app")
    input :url, :argument => true,
      :desc => "URL to route"
    def map(input)
      no_v2

      app = input[:app]

      simple = input[:url].sub(/^https?:\/\/(.*)\/?/i, '\1')

      with_progress("Updating #{c(app.name, :name)}") do
        app.urls << simple
        app.update!
      end
    end


    desc "Remove a URL mapping from an app"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to remove the URL from",
      :from_given => by_name("app")
    input(:url, :argument => true, :desc => "URL to unmap") { |choices|
      ask("Which URL?", :choices => choices)
    }
    def unmap(input)
      no_v2

      app = input[:app]
      url = input[:url, app.urls]

      simple = url.sub(/^https?:\/\/(.*)\/?/i, '\1')

      with_progress("Updating #{c(app.name, :name)}") do |s|
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
    input :app, :argument => true,
      :desc => "Application to inspect the environment of",
      :from_given => by_name("app")
    def env(input)
      app = input[:app]

      vars =
        with_progress("Getting env for #{c(app.name, :name)}") do |s|
          app.env
        end

      line unless quiet?

      vars.each do |name, val|
        line "#{c(name, :name)}: #{val}"
      end
    end


    VALID_ENV_VAR = /^[a-zA-Za-z_][[:alnum:]_]*$/

    desc "Set an environment variable"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to set the variable for",
      :from_given => by_name("app")
    input :name, :argument => true,
      :desc => "Environment variable name"
    input :value, :argument => :optional,
      :desc => "Environment variable value"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def set_env(input)
      app = input[:app]
      name = input[:name]

      if value = input[:value]
        name = input[:name]
      elsif name["="]
        name, value = name.split("=")
      end

      unless name =~ VALID_ENV_VAR
        fail "Invalid variable name; must match #{VALID_ENV_VAR.inspect}"
      end

      with_progress("Updating #{c(app.name, :name)}") do
        app.env[name] = value
        app.update!
      end

      if app.started? && input[:restart]
        invoke :restart, :app => app
      end
    end

    alias_command :set_env, :env_set
    alias_command :set_env, :add_env
    alias_command :set_env, :env_add


    desc "Remove an environment variable"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to set the variable for",
      :from_given => by_name("app")
    input :name, :argument => true,
      :desc => "Environment variable name"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def delete_env(input)
      app = input[:app]
      name = input[:name]

      with_progress("Updating #{c(app.name, :name)}") do
        app.env.delete(name)
        app.update!
      end

      if app.started? && input[:restart]
        invoke :restart, :app => app
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
        line a.name
        return
      end

      status = app_status(a)

      line "#{c(a.name, :name)}: #{status}"

      indented do
        line "platform: #{b(a.framework.name)} on #{b(a.runtime.name)}"

        start_line "usage: #{b(human_size(a.memory * 1024 * 1024, 0))}"
        print " #{d(IS_UTF8 ? "\xc3\x97" : "x")} #{b(a.total_instances)}"
        print " instance#{a.total_instances == 1 ? "" : "s"}"

        line

        unless a.urls.empty?
          line "urls: #{a.urls.collect { |u| b(u) }.join(", ")}"
        end

        unless a.services.empty?
          line "services: #{a.services.collect { |s| b(s.name) }.join(", ")}"
        end
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
            line "Application is in suspended debugging mode."
            line "It will wait for you to attach to it before starting."
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
      start_print "instance #{c("\##{i.index}", :instance)}: "
      puts "#{b(c(i.state.downcase, state_color(i.state)))} "

      indented do
        line "started: #{c(i.since.strftime("%F %r"), :cyan)}"

        if d = i.debugger
          line "debugger: port #{b(d[:port])} at #{b(d[:ip])}"
        end

        if c = i.console
          line "console: port #{b(c[:port])} at #{b(c[:ip])}"
        end
      end
    end

    def find_orphaned_services(apps, others = [])
      orphaned = Set.new

      apps.each do |a|
        a.services.each do |i|
          if others.none? { |x| x.binds?(i) }
            orphaned << i
          end
        end
      end

      orphaned.each(&:invalidate!)
    end

    def delete_orphaned_services(instances, orphaned)
      return if instances.empty?

      line unless quiet?

      instances.select { |i|
        orphaned ||
          ask("Delete orphaned service instance #{c(i.name, :name)}?",
              :default => false)
      }.each do |instance|
        # TODO: splat
        invoke :delete_service, :instance => instance, :really => true
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
