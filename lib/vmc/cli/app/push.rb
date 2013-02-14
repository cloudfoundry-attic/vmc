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
    input :host,      :desc => "Subdomain for the app's URL"
    input :domain,    :desc => "Domain for the app",
                      :from_given => proc { |given, app|
                        if !v2? || given == "none"
                          given
                        else
                          app.space.domain_by_name(given) ||
                            fail_unknown("domain", given)
                        end
                      }
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
      map_route(app)
      create_services(app)
      bind_services(app)
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
      app = filter(:push_app, app)

      with_progress("Uploading #{c(app.name, :name)}") do
        app.upload(path)
      end
    rescue
      err "Upload failed. Try again with 'vmc push'."
      raise
    end

    def wrap_message_format_errors
      yield
    rescue CFoundry::MessageParseError => e
      md = e.description.match /Field: ([^,]+)/
      field = md[1]

      case field
      when "buildpack"
        fail "Buildpack must be a public git repository URI."
      end
    end
  end
end
