require "vmc/cli"

module VMC
  class Service < CLI
    desc "List your services"
    group :services
    input :name, :desc => "Filter by name regexp"
    input :app, :desc => "Filter by bound application regexp"
    input :type, :desc => "Filter by service type regexp"
    input :vendor, :desc => "Filter by service vendor regexp"
    input :tier, :desc => "Filter by service tier regexp"
    def services(input)
      services =
        with_progress("Getting service instances") do
          client.service_instances
        end

      puts "" unless quiet?

      if services.empty? and !quiet?
        puts "No services."
      end

      if app = input[:app]
        apps = client.apps
        services.reject! do |s|
          apps.none? { |a| a.services.include? s.name }
        end
      end

      services.each do |s|
        display_service(s) if service_matches(s, input)
      end
    end


    desc "Create a service"
    group :services, :manage
    input(:service, :argument => true,
          :desc => "What kind of service (e.g. redis, mysql)") { |choices|
      ask "What kind?", :choices => choices
    }
    input(:name, :argument => true,
          :desc => "Local name for the service") { |service|
      random = sprintf("%x", rand(1000000))
      ask "Name?", :default => "#{service.label}-#{random}"
    }
    input(:version, :desc => "Version of the service") { |choices|
      ask "Which version?", :choices => choices
    }
    input :bind, :alias => "--app",
      :desc => "Application to immediately bind to"
    def create_service(input)
      services = client.services

      service_label = input[:service, services.collect(&:label).sort]
      services = services.select { |s| s.label == service_label }

      if services.size == 1
        service = services.first
      else
        version = input[:version, services.collect(&:version).sort]
        service = services.find { |s| s.version == version }
      end

      instance = client.service_instance
      instance.name = input[:name, service]
      instance.type = service.type
      instance.vendor = service.label
      instance.version = service.version
      instance.tier = "free"

      with_progress("Creating service #{c(instance.name, :name)}") do
        instance.create!
      end

      if app = input[:bind]
        invoke :bind_service, :name => instance.name, :app => app
      end

      instance
    end


    desc "Bind a service to an application"
    group :services, :manage
    input(:name, :argument => true,
          :desc => "Service to bind") { |choices|
      ask "Which service?", :choices => choices
    }
    input(:app, :argument => true,
          :desc => "Application to bind to") { |choices|
      ask "Which application?", :choices => choices
    }
    def bind_service(input)
      name = input[:name, client.service_instances.collect(&:name)]
      appname = input[:app, client.apps.collect(&:name)]

      with_progress("Binding #{c(name, :name)} to #{c(appname, :name)}") do
        client.app_by_name(appname).bind(name)
      end
    end


    desc "Unbind a service from an application"
    group :services, :manage
    input(:name, :argument => true,
          :desc => "Service to unbind") { |choices|
      ask "Which service?", :choices => choices
    }
    input(:app, :argument => true,
          :desc => "Application to unbind from") { |choices|
      ask "Which application?", :choices => choices
    }
    def unbind_service(input)
      appname = input[:app, client.apps.collect(&:name)]

      app = client.app_by_name(appname)
      name = input[:name, app.services]

      with_progress("Unbinding #{c(name, :name)} from #{c(appname, :name)}") do
        app.unbind(name)
      end
    end


    desc "Delete a service"
    group :services, :manage
    input(:name, :argument => true,
          :desc => "Service to delete") { |choices|
      ask "Delete which service?", :choices => choices
    }
    input(:really, :type => :boolean) { |name, color|
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    input :all, :default => false, :desc => "Delete all services"
    def delete_service(input)
      if input[:all]
        return unless input[:really, "ALL SERVICES", :bad]

        with_progress("Deleting all services") do
          client.service_instances.collect(&:delete!)
        end

        return
      end

      instances = client.service_instances
      fail "No services." if instances.empty?

      name = input[:name, instances.collect(&:name)]
      service = instances.find { |i| i.name == name }

      return unless input[:really, name, :name]

      with_progress("Deleting #{c(name, :name)}") do
        service.delete!
      end
    end

    private

    def service_matches(s, options)
      if name = options[:name]
        return false if s.name !~ /#{name}/
      end

      if type = options[:type]
        return false if s.type !~ /#{type}/
      end

      if vendor = options[:vendor]
        return false if s.vendor !~ /#{vendor}/
      end

      if tier = options[:tier]
        return false if s.tier !~ /#{tier}/
      end

      true
    end

    def display_service(s)
      if quiet?
        puts s.name
      else
        puts "#{c(s.name, :name)}: #{s.vendor} v#{s.version}"
      end
    end
  end
end
