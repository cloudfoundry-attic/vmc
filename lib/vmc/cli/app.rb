require "set"

require "vmc/cli"
require "vmc/detect"

module VMC
  class App < CLI
    desc "List your applications"
    group :apps
    input :space, :from_given => by_name("space"),
      :default => proc { client.current_space },
      :desc => "Show apps in given space"
    input :name, :desc => "Filter by name regexp"
    input :runtime, :desc => "Filter by runtime regexp"
    input :framework, :desc => "Filter by framework regexp"
    input :url, :desc => "Filter by url regexp"
    input :full, :type => :boolean, :default => false,
      :desc => "Verbose output format"
    def apps
      msg =
        if space = input[:space]
          "Getting applications in #{c(space.name, :name)}"
        else
          "Getting applications"
        end

      apps =
        with_progress(msg) do
          client.apps(2)
        end

      if apps.empty? and !quiet?
        line
        line "No applications."
        return
      end

      line unless quiet?

      apps.reject! do |a|
        !app_matches(a, input)
      end

      apps = apps.sort_by(&:name)

      if input[:full]
        spaced(apps) do |a|
          display_app(a)
        end
      else
        table(
          ["name", "status", "usage", v2? && "plan", "runtime", "url"],
          apps.collect { |a|
            [ c(a.name, :name),
              app_status(a),
              "#{a.total_instances} x #{human_mb(a.memory)}",
              v2? && (a.production ? "prod" : "dev"),
              a.runtime.name,
              if a.urls.empty?
                d("none")
              elsif a.urls.size == 1
                a.url
              else
                "#{a.url}, ..."
              end
            ]
          })
      end
    end


    desc "Show app information"
    group :apps
    input :app, :argument => :required, :from_given => by_name("app"),
      :desc => "App to show"
    def app
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
    input(:memory, :desc => "Memory limit") { |default|
      ask("Memory Limit",
          :choices => memory_choices,
          :allow_other => true,
          :default => default || "64M")
    }
    input(:instances, :type => :integer,
          :desc => "Number of instances to run") {
      ask("Instances", :default => 1)
    }
    input(:framework, :from_given => find_by_name("framework"),
          :desc => "Framework to use") { |all, choices, default, other|
      ask_with_other("Framework", all, choices, default, other)
    }
    input(:runtime, :from_given => find_by_name("runtime"),
          :desc => "Runtime to use") { |all, choices, default, other|
      ask_with_other("Runtime", all, choices, default, other)
    }
    input(:command, :desc => "Startup command for standalone app") {
      ask("Startup command")
    }
    input :plan, :default => "D100",
      :desc => "Application plan (e.g. D100, P200)"
    input :start, :type => :boolean, :default => true,
      :desc => "Start app after pushing?"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    input(:create_services, :type => :boolean,
          :desc => "Interactively create services?") {
      line unless quiet?
      ask "Create services for application?", :default => false
    }
    input(:bind_services, :type => :boolean,
          :desc => "Interactively bind services?") {
      ask "Bind other services to application?", :default => false
    }
    def push
      name = input[:name]
      path = File.expand_path(input[:path])

      if app = client.app_by_name(name)
        sync_app(app, path)
      else
        create_app(name, path)
      end
    end


    desc "Start an application"
    group :apps, :manage
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    input :debug_mode, :aliases => "-d",
      :desc => "Debug mode to start in"
    def start
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
    def stop
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
    def restart
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
    input(:really, :type => :boolean, :forget => true,
          :default => proc { force? || interact }) { |name, color|
      ask("Really delete #{c(name, color)}?", :default => false)
    }
    input :routes, :type => :boolean, :default => false,
      :desc => "Delete associated routes"
    input :orphaned, :aliases => "-o", :type => :boolean,
      :desc => "Delete orphaned instances"
    input :all, :type => :boolean, :default => false,
      :desc => "Delete all applications"
    def delete
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
          app.routes.collect(&:delete!) if input[:routes]
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
    def instances
      apps = input[:apps]
      fail "No applications given." if apps.empty?

      spaced(apps) do |app|
        instances =
          with_progress("Getting instances for #{c(app.name, :name)}") do
            app.instances
          end

        spaced(instances) do |i|
          if quiet?
            line i.id
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
      ask("Memory Limit", :choices => memory_choices(default),
          :allow_other => true,
          :default => human_mb(default))
    }
    input :plan, :default => "D100",
      :desc => "Application plan (e.g. D100, P200)"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def scale
      app = input[:app]

      instances = input.given(:instances)
      memory = input.given(:memory)
      plan_name = input.given(:plan)

      unless instances || memory || plan_name
        instances = input[:instances, app.total_instances]
        memory = input[:memory, app.memory]
      end

      if instances
        instances = instances.to_i
        instances_changed = instances != app.total_instances
      end

      if memory
        memory = megabytes(memory)
        memory_changed = memory != app.memory
      end

      if plan_name
        fail "Plans not supported on target cloud." unless v2?

        production = !!(plan_name =~ /^p/i)
        plan_changed = production != app.production
      end

      unless memory_changed || instances_changed || plan_changed
        fail "No changes!"
      end

      with_progress("Scaling #{c(app.name, :name)}") do
        app.total_instances = instances if instances_changed
        app.memory = memory if memory_changed
        app.production = production if plan_changed
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
    input :instance, :default => "0",
      :desc => "Instance of application to get the logs of"
    input :all, :type => :boolean, :default => false,
      :desc => "Get logs for every instance"
    def logs
      app = input[:app]

      instances =
        if input[:all] || input[:instance] == "all"
          app.instances
        else
          app.instances.select { |i| i.id == input[:instance] }
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
              "Getting logs for #{c(app.name, :name)} " +
                c("\##{i.id}", :instance)) do
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
    def file
      app = input[:app]
      path = input[:path]

      file =
        with_progress("Getting file contents") do
          app.file(*path.split("/"))
        end

      if quiet?
        print file
      else
        line

        file.split("\n").each do |l|
          line l
        end
      end
    rescue CFoundry::APIError => e
      if e.error_code == 190001
        fail "Invalid path #{b(path)} for app #{b(app.name)}"
      else
        raise
      end
    end

    desc "Examine an app's files"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to inspect the files of",
      :from_given => by_name("app")
    input :path, :argument => :optional, :default => "/",
      :desc => "Path of directory to list"
    def files
      app = input[:app]
      path = input[:path]

      if quiet?
        files =
          with_progress("Getting file listing") do
            app.files(*path.split("/"))
          end

        files.each do |file|
          line file.join("/")
        end
      else
        invoke :file, :app => app, :path => path
      end
    rescue CFoundry::APIError => e
      if e.error_code == 190001
        fail "Invalid path #{b(path)} for app #{b(app.name)}"
      else
        raise
      end
    end


    desc "Get application health"
    group :apps, :info, :hidden => true
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    def health
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
    def stats
      app = input[:app]

      stats =
        with_progress("Getting stats for #{c(app.name, :name)}") do
          app.stats
        end

      line unless quiet?

      table(
        %w{instance cpu memory disk},
        stats.sort_by(&:first).collect { |idx, info|
          idx = c("\##{idx}", :instance)

          if info[:state] == "DOWN"
            [idx, c("down", :bad)]
          else
            stats = info[:stats]
            usage = stats[:usage]

            if usage
              [ idx,
                "#{percentage(usage[:cpu])} of #{b(stats[:cores])} cores",
                "#{usage(usage[:mem] * 1024, stats[:mem_quota])}",
                "#{usage(usage[:disk], stats[:disk_quota])}"
              ]
            else
              [idx, c("n/a", :neutral)]
            end
          end
        })
    end


    desc "Add a URL mapping for an app"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to add the URL to",
      :from_given => by_name("app")
    input :url, :argument => true,
      :desc => "URL to map to the application"
    def map
      app = input[:app]

      simple = input[:url].sub(/^https?:\/\/(.*)\/?/i, '\1')

      if v2?
        host, domain_name = simple.split(".", 2)

        domain =
          client.current_space.domains(0, :name => domain_name).first

        fail "Invalid domain '#{domain_name}'" unless domain

        route = client.routes(0, :host => host).find do |r|
          r.domain == domain
        end

        unless route
          route = client.route

          with_progress("Creating route #{c(simple, :name)}") do
            route.host = host
            route.domain = domain
            route.organization = client.current_organization
            route.create!
          end
        end

        with_progress("Binding #{c(simple, :name)} to #{c(app.name, :name)}") do
          app.add_route(route)
        end
      else
        with_progress("Updating #{c(app.name, :name)}") do
          app.urls << simple
          app.update!
        end
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
    def unmap
      app = input[:app]
      url = input[:url, app.urls]

      simple = url.sub(/^https?:\/\/(.*)\/?/i, '\1')

      if v2?
        host, domain_name = simple.split(".", 2)

        domain =
          client.current_space.domains(0, :name => domain_name).first

        fail "Invalid domain '#{domain_name}'" unless domain

        route = app.routes(0, :host => host).find do |r|
          r.domain == domain
        end

        fail "Invalid route '#{simple}'" unless route

        with_progress("Removing route #{c(simple, :name)}") do
          app.remove_route(route)
        end
      else
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
    end


    desc "Show all environment variables set for an app"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to inspect the environment of",
      :from_given => by_name("app")
    def env
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
    def set_env
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


    desc "Remove an environment variable"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to set the variable for",
      :from_given => by_name("app")
    input :name, :argument => true,
      :desc => "Environment variable name"
    input :restart, :type => :boolean, :default => true,
      :desc => "Restart app after updating?"
    def unset_env
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


    desc "DEPRECATED. Use 'push' instead."
    input :app, :argument => :optional
    def update
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

        start_line "usage: #{b(human_mb(a.memory))}"
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

    def sync_app(app, path)
      upload_app(app, path)

      diff = {}

      if input.given?(:memory)
        mem = megabytes(input[:memory])

        if mem != app.memory
          diff[:memory] = [app.memory, mem]
          app.memory = mem
        end
      end

      if input.given?(:instances)
        instances = input[:instances]

        if instances != app.total_instances
          diff[:instances] = [app.total_instances, instances]
          app.total_instances = instances
        end
      end

      if input.given?(:framework)
        all_frameworks = client.frameworks

        framework = input[:framework, all_frameworks, all_frameworks]

        if framework != app.framework
          diff[:framework] = [app.framework.name, framework.name]
          app.framework = framework
        end
      end

      if input.given?(:runtime)
        all_runtimes = client.runtimes

        runtime = input[:runtime, all_runtimes, all_runtimes]

        if runtime != app.runtime
          diff[:runtime] = [app.runtime.name, runtime.name]
          app.runtime = runtime
        end
      end

      if input.given?(:command) && input[:command] != app.command
        command = input[:command]

        if command != app.command
          diff[:command] = [app.command, command]
          app.command = command
        end
      end

      if input.given?(:plan) && v2?
        production = !!(input[:plan] =~ /^p/i)

        if production != app.production
          diff[:production] = [bool(app.production), bool(production)]
          app.production = production
        end
      end

      unless diff.empty?
        line "Changes:"

        indented do
          diff.each do |name, change|
            old, new = change
            line "#{c(name, :name)}: #{old} #{c("->", :dim)} #{new}"
          end
        end

        with_progress("Updating #{c(app.name, :name)}") do
          app.update!
        end
      end

      if input[:restart] && app.started?
        invoke :restart, :app => app
      end
    end

    def create_app(name, path)
      app = client.app
      app.name = name
      app.space = client.current_space if client.current_space
      app.total_instances = input[:instances]
      app.production = !!(input[:plan] =~ /^p/i) if v2?

      detector = Detector.new(client, path)
      all_frameworks = detector.all_frameworks
      all_runtimes = detector.all_runtimes

      if detected_framework = detector.detect_framework
        framework = input[
          :framework,
          all_frameworks,
          [detected_framework],
          detected_framework,
          :other
        ]
      else
        framework = input[:framework, all_frameworks, all_frameworks]
      end


      if framework.name == "standalone"
        detected_runtimes = detector.detect_runtimes
      else
        detected_runtimes = detector.runtimes(framework)
      end

      if detected_runtimes.size == 1
        default_runtime = detected_runtimes.first
      end

      if detected_runtimes.empty?
        runtime = input[:runtime, all_runtimes, all_runtimes]
      else
        runtime = input[
          :runtime,
          all_runtimes,
          detected_runtimes,
          default_runtime,
          :other
        ]
      end


      fail "Invalid framework '#{input[:framework]}'" unless framework
      fail "Invalid runtime '#{input[:runtime]}'" unless runtime

      app.framework = framework
      app.runtime = runtime

      app.command = input[:command] if framework.name == "standalone"

      url =
        if framework.name == "standalone"
          if (given = input[:url, "none"]) != "none"
            given
          end
        else
          input[:url, "#{name}.#{target_base}"]
        end

      app.urls = [url] if url && !v2?

      default_memory = detector.suggested_memory(framework) || 64
      app.memory = megabytes(input[:memory, human_mb(default_memory)])

      app = filter(:create_app, app)

      with_progress("Creating #{c(app.name, :name)}") do
        app.create!
      end

      invoke :map, :app => app, :url => url if url && v2?

      bindings = []

      if input[:create_services] && !force?
        while true
          invoke :create_service, { :app => app }, :plan => :interact
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
      start_line "instance #{c("\##{i.id}", :instance)}: "
      puts "#{b(c(i.state.downcase, state_color(i.state)))} "

      indented do
        if s = i.since
          line "started: #{c(s.strftime("%F %r"), :cyan)}"
        end

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

      line unless quiet? || force?

      instances.select { |i|
        orphaned ||
          ask("Delete orphaned service instance #{c(i.name, :name)}?",
              :default => false)
      }.each do |instance|
        # TODO: splat
        invoke :delete_service, :instance => instance, :really => true
      end
    end

    def ask_with_other(message, all, choices, default, other)
      choices = choices.sort_by(&:name)
      choices << other if other

      opts = {
        :choices => choices,
        :display => proc { |x|
          if other && x == other
            "other"
          else
            x.name
          end
        }
      }

      opts[:default] = default if default

      res = ask(message, opts)

      if other && res == other
        opts[:choices] = all
        res = ask(message, opts)
      end

      res
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

    def human_mb(num)
      human_size(num * 1024 * 1024, 0)
    end

    def target_base
      client.target.sub(/^https?:\/\/([^\.]+\.)?(.+)\/?/, '\2')
    end

    def memory_choices(exclude = 0)
      info = client.info
      used = info[:usage][:memory]
      limit = info[:limits][:memory]
      available = limit - used + exclude

      mem = 64
      choices = []
      until mem > available
        choices << human_mb(mem)
        mem *= 2
      end

      choices
    end

    def bool(b)
      if b
        c("true", :yes)
      else
        c("false", :no)
      end
    end
  end
end
