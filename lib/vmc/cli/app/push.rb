require "vmc/cli/app/base"
require "vmc/cli/app/push/sync"
require "vmc/cli/app/push/create"
require "vmc/cli/app/push/interactions"

module VMC::App
  class Push < Base
    include Sync
    include Create

    desc "Push an application, syncing changes if it exists"
    group :apps, :manage
    input :name,      :desc => "Application name", :argument => :optional
    input :path,      :desc => "Path containing the bits", :default => "."
    input :url,       :desc => "URL to bind to app"
    input :memory,    :desc => "Memory limit"
    input :instances, :desc => "Number of instances to run", :type => :integer
    input :framework, :desc => "Framework to use", :from_given => by_name(:framework)
    input :runtime,   :desc => "Runtime to use", :from_given => by_name(:runtime)
    input :command,   :desc => "Startup command"
    input :plan,      :desc => "Application plan", :default => "D100"
    input :start,     :desc => "Start app after pushing?", :default => true
    input :restart,   :desc => "Restart app after updating?", :default => true
    input :buildpack, :desc => "Custom buildpack URL", :default => nil
    input :create_services, :desc => "Interactively create services?",
          :type => :boolean, :default => proc { force? ? false : interact }
    input :bind_services, :desc => "Interactively bind services?",
          :type => :boolean, :default => proc { force? ? false : interact }
    interactions PushInteractions

    def push
      name = input[:name]
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
  end
end
