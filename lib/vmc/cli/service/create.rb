require "vmc/detect"

require "vmc/cli/service/base"

module VMC::Service
  class Create < Base
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
          :default => proc { |plans|
            plans.find { |p| p.name == "D100" } ||
              interact
          },
          :from_given => find_by_name_insensitive("plan")) { |plans|
      ask "Which plan?", :choices => plans.sort_by(&:name),
        :display => proc { |p| "#{p.name}: #{p.description}" },
        :complete => proc(&:name)
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
      elsif !v2?
        services.reject!(&:deprecated?)
      end

      if v2? && plan = input.given(:plan)
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
  end
end
