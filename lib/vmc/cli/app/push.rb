require "vmc/detect"

require "vmc/cli/app/base"

module VMC::App
  class Push < Base
    desc "Push an application, syncing changes if it exists"
    group :apps, :manage
    input(:name, :argument => true, :desc => "Application name") {
      ask("Name")
    }
    input :path, :default => ".",
      :desc => "Path containing the application"
    input(:url, :desc => "URL bound to app") { |name|
      choices = url_choices(name)

      options = {
        :choices => choices + ["none"],
        :allow_other => true
      }

      options[:default] = choices.first if choices.size == 1

      url = ask "URL", options

      unless url == "none"
        url
      end
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
        upload_app(app, path)
        sync_app(app)
      else
        create_app(name, path)
      end
    end

    def sync_app(app)

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

      detector = VMC::Detector.new(client, path)
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

      default_memory = detector.suggested_memory(framework) || 64
      app.memory = megabytes(input[:memory, human_mb(default_memory)])

      app = filter(:create_app, app)

      with_progress("Creating #{c(app.name, :name)}") do
        app.create!
      end

      line unless quiet?

      url = input[:url, name]

      mapped_url = false
      until !url || mapped_url
        begin
          invoke :map, :app => app, :url => url
          mapped_url = true
        rescue CFoundry::RouteHostTaken, CFoundry::UriAlreadyTaken => e
          line c(e.description, :bad)
          line

          input.forget(:url)
          url = input[:url, name]

          # version bumps on v1 even though mapping fails
          app.invalidate! unless v2?
        end
      end

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

    private

    def upload_app(app, path)
      with_progress("Uploading #{c(app.name, :name)}") do
        app.upload(path)
      end
    end

    def bool(b)
      if b
        c("true", :yes)
      else
        c("false", :no)
      end
    end

    def url_choices(name)
      if v2?
        client.current_space.domains.sort_by(&:name).collect do |d|
          # TODO: check availability
          "#{name}.#{d.name}"
        end
      else
        ["#{name}.#{target_base}"]
      end
    end

    def target_base
      client.target.sub(/^https?:\/\/([^\.]+\.)?(.+)\/?/, '\2')
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
  end
end
