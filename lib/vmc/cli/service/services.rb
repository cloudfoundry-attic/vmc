require "vmc/cli/service/base"

module VMC::Service
  class Services < Base
    desc "List your service"
    group :services
    input :space, :desc => "Show services in given space",
          :from_given => by_name(:space),
          :default => proc { client.current_space }
    input :name, :desc => "Filter by name"
    input :service, :desc => "Filter by service type"
    input :plan, :desc => "Filter by service plan"
    input :provider, :desc => "Filter by service provider"
    input :version, :desc => "Filter by service version"
    input :app, :desc => "Limit to application's service bindings",
          :from_given => by_name(:app)
    input :full, :desc => "Verbose output format", :default => false
    def services
      msg =
        if space = input[:space]
          "Getting services in #{c(space.name, :name)}"
        else
          "Getting services"
        end

      services =
        with_progress(msg) do
          client.service_instances(:depth => 2)
        end

      line unless quiet?

      if services.empty? and !quiet?
        line "No services."
        return
      end

      services.reject! do |i|
        !service_matches(i, input)
      end

      if input[:full]
        spaced(services) do |s|
          invoke :service, :service => s
        end
      else
        table(
          ["name", "service", "version", v2? && "plan", v2? && "bound apps"],
          services.collect { |i|
            if v2?
              plan = i.service_plan
              service = plan.service

              label = service.label
              version = service.version
              apps = name_list(i.service_bindings.collect(&:app))
            else
              label = i.vendor
              version = i.version
            end

            [ c(i.name, :name),
              label,
              version,
              v2? && plan.name,
              apps
            ]
          })
      end
    end

    private

    def service_matches(i, options)
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
  end
end
