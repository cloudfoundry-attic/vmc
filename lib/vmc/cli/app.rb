require "vmc/cli/command"
require "vmc/detect"

module VMC
  class App < Command
    MEM_CHOICES = ["64M", "128M", "256M", "512M"]

    desc "apps", "List your applications"
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

    desc "health ...APPS", "Get application health"
    def health(*names)
      apps =
        with_progress("Getting application health") do
          names.collect do |n|
            [n, app_status(client.app(n))]
          end
        end

      apps.each do |name, status|
        unless simple_output?
          puts ""
          print "#{c(name, :blue)}: "
        end

        puts status
      end
    end

    desc "stop [APP]", "Stop an application"
    def stop(name)
      with_progress("Stopping #{c(name, :blue)}") do |s|
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

    desc "start [APP]", "Start an application"
    flag(:debug_mode)
    def start(name)
      app = client.app(name)

      unless app.exists?
        err "Unknown application."
        return
      end

      switch_mode(app, input(:debug_mode))

      with_progress("Starting #{c(name, :blue)}") do |s|
        if app.running?
          s.skip do
            err "Already started."
            return
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

    desc "restart [APP]", "Stop and start an application"
    flag(:debug_mode)
    def restart(name)
      stop(name)
      start(name)
    end

    desc "delete [APP]", "Delete an application"
    flag(:really) { |name, color|
      color ||= :blue
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    flag(:name) { |names|
      ask("Delete which application?", :choices => names)
    }
    flag(:all, :default => false)
    def delete(name = nil)
      if input(:all)
        return unless input(:really, "ALL APPS", :red)

        with_progress("Deleting all applications") do
          client.apps.collect(&:delete!)
        end

        return
      end

      unless name
        apps = client.apps
        return err "No applications." if apps.empty?

        name = input(:name, apps.collect(&:name))
      end

      return unless input(:really, name)

      with_progress("Deleting #{c(name, :blue)}") do
        client.app(name).delete!
      end
    ensure
      forget(:really)
    end

    desc "instances [APP]", "List an app's instances"
    def instances(name)
      instances =
        with_progress("Getting instances for #{c(name, :blue)}") do
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

    desc "files [APP] [PATH]", "Examine an app's files"
    def files(name, path = "/")
      files =
        with_progress("Getting file listing") do
          client.app(name).files(*path.split("/"))
        end

      puts "" unless simple_output?

      files.each do |file|
        puts file
      end
    end

    desc "file [APP] [PATH]", "Print out an app's file contents"
    def file(name, path = "/")
      file =
        with_progress("Getting file contents") do
          client.app(name).file(*path.split("/"))
        end

      puts "" unless simple_output?

      print file
    end

    desc "logs [APP]", "Print out an app's logs"
    flag(:instance, :type => :numeric, :default => 0)
    flag(:all, :default => false)
    def logs(name)
      app = client.app(name)
      unless app.exists?
        err "Unknown application."
        return
      end

      instances =
        if input(:all)
          app.instances
        else
          app.instances.select { |i| i.index == input(:instance) }
        end

      if instances.empty?
        if input(:all)
          err "No instances found."
        else
          err "Instance #{name} \##{input(:instance)} not found."
        end

        return
      end

      instances.each do |i|
        logs =
          with_progress(
            "Getting logs for " +
              c(name, :blue) + " " +
              c("\##{i.index}", :yellow)) do
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

    desc "push [NAME]", "Push an application, syncing changes if it exists"
    flag(:name) { ask("Name") }
    flag(:path) {
      ask("Push from...", :default => ".")
    }
    flag(:url) { |name, target|
      ask("URL", :default => "#{name}.#{target}")
    }
    flag(:memory) {
      ask("Memory Limit",
          :choices => MEM_CHOICES,

          # TODO: base this on framework choice
          :default => "64M")
    }
    flag(:instances) {
      ask("Instances", :default => 1)
    }
    flag(:framework) { |choices, default|
      ask("Framework", :choices => choices, :default => default)
    }
    flag(:runtime) { |choices|
      ask("Runtime", :choices => choices)
    }
    flag(:start, :default => true)
    flag(:restart, :default => true)
    def push(name = nil)
      path = File.expand_path(input(:path))

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

      domain = client.target.sub(/^https?:\/\/api\.(.+)\/?/, '\1')
      app.urls = [input(:url, name, domain)]

      framework = input(:framework, ["other"] + detected.keys, default)
      if framework == "other"
        forget(:framework)
        framework = input(:framework, frameworks.keys)
      end

      framework_runtimes =
        frameworks[framework]["runtimes"].collect do |k|
          "#{k["name"]} (#{k["description"]})"
        end

      # TODO: include descriptions
      runtime = input(:runtime, *framework_runtimes).split.first

      app.framework = framework
      app.runtime = runtime

      app.memory = megabytes(input(:memory))

      with_progress("Creating #{c(name, :blue)}") do
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

    desc "update", "DEPRECATED", :hide => true
    def update(*args)
      err "The 'update' command is no longer used; use 'push' instead."
    end

    desc "stats [APP]", "Display application instance status"
    def stats(name)
      stats =
        with_progress("Getting stats") do
          client.app(name).stats
        end

      stats.sort_by { |k, _| k }.each do |idx, info|
        stats = info["stats"]
        usage = stats["usage"]
        puts ""
        puts "instance #{c("#" + idx, :blue)}:"
        print "  cpu: #{percentage(usage["cpu"])} of"
        puts " #{b(stats["cores"])} cores"
        puts "  memory: #{usage(usage["mem"] * 1024, stats["mem_quota"])}"
        puts "  disk: #{usage(usage["disk"], stats["disk_quota"])}"
      end
    end

    desc "scale [APP]", "Update the instances/memory limit for an application"
    flag(:instances, :type => :numeric) { |default|
      ask("Instances", :default => default)
    }
    flag(:memory) { |default|
      ask("Memory Limit",
          :default => human_size(default * 1024 * 1024, 0),
          :choices => MEM_CHOICES)
    }
    def scale(name)
      app = client.app(name)

      instances = passed_value(:instances)
      memory = passed_value(:memory)

      unless instances || memory
        instances = input(:instances, app.total_instances)
        memory = input(:memory, app.memory)
      end

      with_progress("Scaling #{c(name, :blue)}") do
        app.total_instances = instances.to_i if instances
        app.memory = megabytes(memory) if memory
        app.update!
      end
    end

    desc "map NAME URL", "Add a URL mapping for an app"
    def map(name, url)
      simple = url.sub(/^https?:\/\/(.*)\/?/i, '\1')

      with_progress("Updating #{c(name, :blue)}") do
        app = client.app(name)
        app.urls << simple
        app.update!
      end
    end

    desc "unmap NAME URL", "Remove a URL mapping from an app"
    def unmap(name, url)
      simple = url.sub(/^https?:\/\/(.*)\/?/i, '\1')

      with_progress("Updating #{c(name, :blue)}") do |s|
        app = client.app(name)

        unless app.urls.delete(simple)
          s.fail do
            err "URL #{url} is not mapped to this application."
            return
          end
        end

        app.update!
      end
    end

    class Env < Command
      VALID_NAME = /^[a-zA-Za-z_][[:alnum:]_]*$/

      desc "set [APP] [NAME] [VALUE]", "Set an environment variable"
      def set(appname, name, value)
        app = client.app(appname)
        unless name =~ VALID_NAME
          err "Invalid variable name; must match #{VALID_NAME.inspect}"
          return
        end

        unless app.exists?
          err "Unknown application."
          return
        end

        with_progress("Updating #{c(app.name, :blue)}") do
          app.update!("env" =>
                        app.env.reject { |v|
                          v.start_with?("#{name}=")
                        }.push("#{name}=#{value}"))
        end
      end

      desc "unset [APP] [NAME]", "Remove an environment variable"
      def unset(appname, name)
        app = client.app(appname)

        unless app.exists?
          err "Unknown application."
          return
        end

        with_progress("Updating #{c(app.name, :blue)}") do
          app.update!("env" =>
                        app.env.reject { |v|
                          v.start_with?("#{name}=")
                        })
        end
      end

      desc "list [APP]", "Show all environment variables set for an app"
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
          puts "#{c(name, :blue)}: #{val}"
        end
      end
    end

    desc "env SUBCOMMAND ...ARGS", "Manage application environment variables"
    subcommand "env", Env

    private

    def upload_app(app, path)
      with_progress("Uploading #{c(app.name, :blue)}") do
        app.upload(path)
      end
    end

    # set app debug mode, ensuring it's valid, and shutting it down
    def switch_mode(app, mode)
      mode = nil if mode == "none"

      return false if app.debug_mode == mode

      if mode.nil?
        with_progress("Removing debug mode") do
          app.debug_mode = nil
          app.stop! if app.running?
        end

        return true
      end

      with_progress("Switching mode to #{c(mode, :blue)}") do |s|
        runtimes = client.system_runtimes
        modes = runtimes[app.runtime]["debug_modes"] || []
        if modes.include?(mode)
          app.debug_mode = mode
          app.stop! if app.running?
          true
        else
          s.fail do
            err "Unknown mode '#{mode}'; available: #{modes.inspect}"
            false
          end
        end
      end
    end

    APP_CHECK_LIMIT = 60

    def check_application(app)
      with_progress("Checking #{c(app.name, :blue)}") do |s|
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
        :blue
      when "STARTED", "RUNNING"
        :green
      when "DOWN"
        :red
      when "FLAPPING"
        :magenta
      when "N/A"
        :cyan
      else
        :yellow
      end
    end

    def app_status(a)
      health = a.health

      if a.debug_mode == "suspend" && health == "0%"
        c("suspended", :yellow)
      else
        c(health.downcase, state_color(health))
      end
    end

    def display_app(a)
      if simple_output?
        puts a.name
        return
      end

      puts ""

      status = app_status(a)

      print "#{c(a.name, :blue)}: #{status}"

      unless a.total_instances == 1
        print ", #{b(a.total_instances)} instances"
      end

      puts ""

      unless a.urls.empty?
        puts "  urls: #{a.urls.collect { |u| b(u) }.join(", ")}"
      end

      unless a.services.empty?
        puts "  services: #{a.services.collect { |s| b(s) }.join(", ")}"
      end
    end

    def display_instance(i)
      print "instance #{c("\##{i.index}", :blue)}: "
      puts "#{b(c(i.state.downcase, state_color(i.state)))} "

      puts "  started: #{c(i.since.strftime("%F %r"), :cyan)}"

      if d = i.debugger
        puts "  debugger: port #{c(d["port"], :blue)} at #{c(d["ip"], :blue)}"
      end

      if c = i.console
        puts "  console: port #{b(c["port"])} at #{b(c["ip"])}"
      end
    end
  end
end
