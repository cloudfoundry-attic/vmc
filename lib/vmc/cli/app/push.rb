require "vmc/detect"
require "vmc/cli/app/base"
require "vmc/cli/app/push/sync"
require "vmc/cli/app/push/create"

module VMC::App
  class Push < Base
    include Sync
    include Create

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
    input(:framework, :from_given => by_name("framework"),
          :desc => "Framework to use") { |choices, default, other|
      ask_with_other("Framework", client.frameworks, choices, default, other)
    }
    input(:runtime, :from_given => by_name("runtime"),
          :desc => "Runtime to use") { |choices, default, other|
      ask_with_other("Runtime", client.runtimes, choices, default, other)
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
          :default => proc { force? ? false : interact },
          :desc => "Interactively create services?") {
      line unless quiet?
      ask "Create services for application?", :default => false
    }
    input(:bind_services, :type => :boolean,
          :default => proc { force? ? false : interact },
          :desc => "Interactively bind services?") {
      unless all_instances.empty?
        ask "Bind other services to application?", :default => false
      end
    }
    def push
      path = File.expand_path(input[:path])
      app = client.app_by_name(name)

      if app
        sync_app(app, path)
      else
        setup_new_app(path)
      end
    end

    def sync_app(app, path)
      upload_app(app, path)
      apply_changes(app)
      display_changes(app)
      commit_changes(app)
    end

    def setup_new_app(path)
      self.path = path
      app = create_app(get_inputs)
      map_url(app)
      create_services(app)
      bind_services(app)
      app = filter(:push_app, app)
      upload_app(app, path)
      start_app(app)
    end

    private

    def url_choices(name)
      if v2?
        client.current_space.domains.sort_by(&:name).collect do |d|
          # TODO: check availability
          "#{name}.#{d.name}"
        end
      else
        %W(#{name}.#{target_base})
      end
    end

    def upload_app(app, path)
      with_progress("Uploading #{c(app.name, :name)}") do
        app.upload(path)
      end
    rescue
      err "Upload failed. Try again with 'vmc push'."
      raise
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
