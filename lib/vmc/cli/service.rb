require "vmc/cli"

module VMC
  class Service < CLI
    def self.find_by_name(what)
      proc { |name, choices|
        choices.find { |c| c.name == name } ||
          fail("Unknown #{what} '#{name}'")
      }
    end

    def self.by_name(what, obj = what)
      proc { |name, *_|
        client.send(:"#{obj}_by_name", name) ||
          fail("Unknown #{what} '#{name}'")
      }
    end

    desc "List your service instances"
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

    desc "Create a service"
    group :services, :manage
    input(:service, :argument => true,
          :desc => "What kind of service (e.g. redis, mysql)",
          :from_given => services_from_label) { |services|
      [ask("What kind?", :choices => services.sort_by(&:label),
           :display => proc { |s|
              str = "#{c(s.label, :name)} v#{s.version}"
              if s.provider != "core"
                str << ", via #{s.provider}"
              end
              str
           },
           :complete => proc { |s| "#{s.label} v#{s.version}" })]
    }
    input(:name, :argument => true,
          :desc => "Name for your instance") { |service|
      random = sprintf("%x", rand(1000000))
      ask "Name?", :default => "#{service.label}-#{random}"
    }
    input(:plan, :desc => "Service plan",
          :from_given => find_by_name("plan")) { |plans|
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
    def create_service(input)
      services = client.services

      if input[:provider]
        services.reject! { |s| s.provider != input[:provider] }
      end

      if input[:version]
        services.reject! { |s| s.version != input[:version] }
      end

      until services.size < 2
        services = input[:service, services]
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

      if app = input[:app]
        invoke :bind_service, :instance => instance, :app => app
      end

      instance
    end


    desc "Bind a service instance to an application"
    group :services, :manage
    input(:instance, :argument => true,
          :from_given => by_name("instance", :service_instance),
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
    def bind_service(input)
      app = input[:app]
      instance = input[:instance, app]

      with_progress(
          "Binding #{c(instance.name, :name)} to #{c(app.name, :name)}") do
        app.bind(instance)
      end
    end


    desc "Unbind a service from an application"
    group :services, :manage
    input(:instance, :argument => true,
          :from_given => find_by_name("instance"),
          :desc => "Service to bind") { |instances|
      ask "Which service instance?", :choices => instances,
        :display => proc(&:name)
    }
    input(:app, :argument => true,
          :from_given => find_by_name("app"),
          :desc => "Application to bind to") { |apps|
      ask "Which application?", :choices => apps,
        :display => proc(&:name)
    }
    def unbind_service(input)
      app = input[:app, client.apps(2)]
      instance = input[:instance, app.services]

      with_progress(
          "Unbinding #{c(instance.name, :name)} from #{c(app.name, :name)}") do
        app.unbind(instance)
      end
    end


    desc "Delete a service"
    group :services, :manage
    input(:instance, :argument => true,
          :from_given => find_by_name("instance"),
          :desc => "Service to bind") { |instances|
      ask "Which service instance?", :choices => instances,
        :display => proc(&:name)
    }
    input(:really, :type => :boolean, :forget => true) { |name, color|
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    input :all, :default => false, :desc => "Delete all services"
    def delete_service(input)
      if input[:all]
        return unless input[:really, "ALL SERVICES", :bad]

        client.service_instances.each do |i|
          with_progress("Deleting #{c(i.name, :name)}") do
            i.delete!
          end
        end

        return
      end

      instances = client.service_instances
      fail "No services." if instances.empty?

      instance = input[:instance, instances]

      return unless input[:really, instance.name, :name]

      with_progress("Deleting #{c(instance.name, :name)}") do
        instance.delete!
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
