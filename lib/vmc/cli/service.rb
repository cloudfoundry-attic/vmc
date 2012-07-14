require "vmc/cli"

module VMC
  class Service < CLI
    desc "List your services"
    group :services
    input :name, :desc => "Filter by name regexp"
    input :app, :desc => "Filter by bound application regexp"
    input :service, :desc => "Filter by service regexp"
    # TODO: not in v2
    input :type, :desc => "Filter by service type regexp"
    input :tier, :desc => "Filter by service tier regexp"
    def services(input)
      instances =
        with_progress("Getting service instances") do
          client.service_instances(2)
        end

      if instances.empty? and !quiet?
        puts ""
        puts "No services."
      end

      instances.each.with_index do |i, n|
        display_instance(i) if instance_matches(i, input)
      end
    end

    services_from_label = proc { |label, services|
      services.select { |s| s.label == label }
    }

    plan_from_name = proc { |name, plans|
      plans.find { |p| p.name == name }
    }

    desc "Create a service"
    group :services, :manage
    input(:service, :argument => true,
          :desc => "What kind of service (e.g. redis, mysql)",
          :from_given => services_from_label) { |services|
      [ask("What kind?", :choices => services.sort_by(&:label),
           :display => proc { |s| "#{c(s.label, :name)} v#{s.version}" },
           :complete => proc { |s| "#{s.label} v#{s.version}" })]
    }
    input(:name, :argument => true,
          :desc => "Name for your instance") { |service|
      random = sprintf("%x", rand(1000000))
      ask "Name?", :default => "#{service.label}-#{random}"
    }
    input(:version, :desc => "Version of the service") { |services|
      ask "Which version?", :choices => services,
        :display => proc(&:version)
    }
    input(:plan, :desc => "Service plan",
          :from_given => plan_from_name) { |plans|
      ask "Which plan?", :choices => plans.sort_by(&:name),
        :display => proc { |p| "#{p.name}: #{p.description}" },
        :complete => proc(&:name)
    }
    input :bind, :alias => "--app",
      :desc => "Application to immediately bind to"
    def create_service(input)
      services = client.services

      services = input[:service, services]

      if services.size == 1
        service = services.first
      else
        service = input[:version, services]
      end

      plans = service.service_plans
      plan = plans.find { |p| p.name == "D100" } || input[:plan, plans]

      instance = client.service_instance
      instance.name = input[:name, service]

      if v2?
        instance.service_plan = plan
        instance.space = client.current_space
        instance.credentials = {} # TODO: ?
      else
        instance.type = service.type
        instance.vendor = service.label
        instance.version = service.version
        instance.tier = "free"
      end

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
    input(:really, :type => :boolean, :forget => true) { |name, color|
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

    def instance_matches(i, options)
      if app = options[:app]
        return false if i.service_bindings.none? { |b|
          b.app.name == app
        }
      end

      if name = options[:name]
        return false if i.name !~ /#{name}/
      end

      if service = options[:service]
        return false if i.service_plan.service.label !~ /#{service}/
      end

      if !v2? && type = options[:type]
        return false if i.type !~ /#{type}/
      end

      if !v2? && tier = options[:tier]
        return false if i.tier !~ /#{tier}/
      end

      true
    end

    def display_instance(i)
      if quiet?
        puts i.name
      else
        plan = i.service_plan
        service = plan.service

        puts ""
        puts "#{c(i.name, :name)}: #{service.label} v#{service.version}"
        puts "  description: #{service.description}"
        puts "  plan: #{c(plan.name, :name)}"
        puts "    description: #{plan.description}"
      end
    end
  end
end
