require "vmc/cli"

module VMC
  class Service < CLI
    desc "List your service instances"
    group :services
    input :name, :desc => "Filter by name"
    input :service, :desc => "Filter by service type"
    input :plan, :desc => "Filter by service plan"
    input :provider, :desc => "Filter by service provider"
    input :version, :desc => "Filter by service version"
    input :app, :desc => "Limit to application's service bindings",
      :from_given => by_name("app")
    def services
      instances =
        with_progress("Getting service instances") do
          client.service_instances(2)
        end

      line unless quiet?

      if instances.empty? and !quiet?
        line "No services."
      end

      instances.reject! do |i|
        !instance_matches(i, input)
      end

      spaced(instances) do |i|
        display_service_instance(i)
      end
    end


    desc "Show service instance information"
    group :services
    input :instance, :argument => :required,
      :from_given => by_name("service instance", :service_instance),
      :desc => "Service instance to show"
    def service
      display_service_instance(input[:instance])
    end


    services_from_label = proc { |label, services|
      services.select { |s| s.label == label }
    }

    desc "Create a service"
    group :services, :manage
    input(:service, :argument => true,
          :desc => "What kind of service (e.g. redis, mysql)",
          :from_given => services_from_label) { |services|
      [ask("What kind?", :choices => services.sort_by(&:label),
           :display => proc { |s|
              str = "#{c(s.label, :name)} #{s.version}"
              if s.provider != "core"
                str << ", via #{s.provider}"
              end
              str
           },
           :complete => proc { |s| "#{s.label} #{s.version}" })]
    }
    input(:name, :argument => true,
          :desc => "Name for your instance") { |service|
      random = sprintf("%x", rand(1000000))
      ask "Name?", :default => "#{service.label}-#{random}"
    }
    input(:plan, :desc => "Service plan",
          :from_given => find_by_name_insensitive("plan")) { |plans|
      if d100 = plans.find { |p| p.name == "D100" }
        d100
      else
        ask "Which plan?", :choices => plans.sort_by(&:name),
          :display => proc { |p| "#{p.name}: #{p.description}" },
          :complete => proc(&:name)
      end
    }
    input :provider, :desc => "Service provider"
    input :version, :desc => "Service version"
    input :app, :alias => "--bind", :from_given => by_name("app"),
      :desc => "Application to immediately bind to"
    def create_service
      services = client.services

      if input[:provider]
        services.reject! { |s| s.provider != input[:provider] }
      end

      if input[:version]
        services.reject! { |s| s.version != input[:version] }
      end

      if plan = input.given(:plan)
        services.reject! do |s|
          if plan.is_a?(String)
            s.service_plans.none? { |p| p.name == plan.upcase }
          else
            s.service_plans.include? plan
          end
        end
      end

      until services.size < 2
        # cast to Array since it might be given as a Service with #invoke
        services = Array(input[:service, services.sort_by(&:label)])
        input.forget(:service)
      end

      if services.empty?
        fail "Cannot find services matching the given criteria."
      end

      service = services.first

      instance = client.service_instance
      instance.name = input[:name, service]

      if v2?
        instance.service_plan = input[:plan, service.service_plans]
        instance.space = client.current_space
      else
        instance.type = service.type
        instance.vendor = service.label
        instance.version = service.version
        instance.tier = "free"
      end

      with_progress("Creating service #{c(instance.name, :name)}") do
        instance.create!
      end

      if app = input[:app]
        invoke :bind_service, :instance => instance, :app => app
      end

      instance
    end


    desc "Bind a service instance to an application"
    group :services, :manage
    input(:instance, :argument => true,
          :from_given => by_name("service instance", :service_instance),
          :desc => "Service to bind") { |app|
      instances = client.service_instances
      fail "No service instances." if instances.empty?

      ask "Which service instance?",
        :choices => instances - app.services,
        :display => proc(&:name)
    }
    input(:app, :argument => true,
          :from_given => by_name("app"),
          :desc => "Application to bind to") {
      ask "Which application?", :choices => client.apps(2),
        :display => proc(&:name)
    }
    def bind_service
      app = input[:app]
      instance = input[:instance, app]

      with_progress(
          "Binding #{c(instance.name, :name)} to #{c(app.name, :name)}") do |s|
        if app.binds?(instance)
          s.skip do
            err "App #{b(app.name)} already binds #{b(instance.name)}."
          end
        else
          app.bind(instance)
        end
      end
    end


    desc "Unbind a service from an application"
    group :services, :manage
    input(:instance, :argument => true,
          :from_given => find_by_name("service instance"),
          :desc => "Service to bind") { |app|
      ask "Which service instance?", :choices => app.services,
        :display => proc(&:name)
    }
    input(:app, :argument => true,
          :from_given => find_by_name("app"),
          :desc => "Application to bind to") {
      ask "Which application?", :choices => client.apps(2),
        :display => proc(&:name)
    }
    def unbind_service
      app = input[:app]
      instance = input[:instance, app]

      with_progress(
          "Unbinding #{c(instance.name, :name)} from #{c(app.name, :name)}") do
        app.unbind(instance)
      end
    end


    desc "Delete a service"
    group :services, :manage
    input(:instance, :argument => true,
          :from_given => by_name("service instance", :service_instance),
          :desc => "Service to bind") {
      instances = client.service_instances
      fail "No services." if instances.empty?

      ask "Which service instance?", :choices => instances,
        :display => proc(&:name)
    }
    input(:really, :type => :boolean, :forget => true) { |name, color|
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    input :all, :default => false, :desc => "Delete all services"
    def delete_service
      if input[:all]
        return unless input[:really, "ALL SERVICES", :bad]

        client.service_instances.each do |i|
          invoke :delete_service, :instance => i, :really => true
        end

        return
      end

      instance = input[:instance]

      return unless input[:really, instance.name, :name]

      with_progress("Deleting #{c(instance.name, :name)}") do |s|
        bindings = v2? ? instance.service_bindings : []

        if bindings.empty?
          instance.delete!
        else
          s.skip do
            apps = bindings.collect(&:app).collect { |a| b(a.name) }
            err "Service instance is bound to #{human_list(apps)}."
          end
        end
      end
    end

    private

    def instance_matches(i, options)
      if app = options[:app]
        return false unless app.services.include? i
      end

      if name = options[:name]
        return false unless File.fnmatch(name, i.name)
      end

      plan = i.service_plan if v2?

      if service = options[:service]
        if v2?
          return false unless File.fnmatch(service, plan.service.label)
        else
          return false unless File.fnmatch(service, i.vendor)
        end
      end

      if plan = options[:plan]
        fail "--plan is not supported on this target" unless v2?
        return false unless File.fnmatch(plan.upcase, plan.name.upcase)
      end

      if provider = options[:provider]
        fail "--provider is not supported on this target" unless v2?
        return false unless File.fnmatch(provider, plan.service.provider)
      end

      if version = options[:version]
        if v2?
          return false unless File.fnmatch(version, plan.service.version)
        else
          return false unless File.fnmatch(version, i.version)
        end
      end

      true
    end

    def display_service_instance(i)
      if quiet?
        line i.name
      elsif v2?
        plan = i.service_plan
        service = plan.service

        line "#{c(i.name, :name)}: #{service.label} #{service.version}"

        indented do
          line "description: #{service.description}"
          line "provider: #{c(service.provider, :name)}"
          line "plan: #{c(plan.name, :name)}"

          indented do
            line "description: #{plan.description}"
          end
        end
      else
        line "#{c(i.name, :name)}: #{i.vendor} #{i.version}"
      end
    end

    def human_list(xs)
      if xs.size == 1
        xs.first
      elsif xs.size == 2
        "#{xs.first} and #{xs.last}"
      else
        last = xs.pop
        xs.join(", ") + ", and #{last}"
      end
    end
  end
end
