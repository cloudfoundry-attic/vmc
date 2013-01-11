require "vmc/cli/service/base"

module VMC::Service
  class Create < Base
    offerings_from_label = proc { |label, offerings|
      offerings.select { |s| s.label == label }
    }

    desc "Create a service"
    group :services, :manage
    input :offering, :desc => "What kind of service (e.g. redis, mysql)",
          :argument => :optional, :from_given => offerings_from_label
    input :name, :desc => "Name for your service", :argument => :optional
    input :plan, :desc => "Service plan",
          :from_given => find_by_name_insensitive("plan"),
          :default => proc { |plans|
            plans.find { |p| p.name == "D100" } ||
              interact
          }
    input :provider, :desc => "Service provider"
    input :version, :desc => "Service version"
    input :app, :desc => "Application to immediately bind to",
          :alias => "--bind", :from_given => by_name(:app)
    def create_service
      offerings = client.services

      if input[:provider]
        offerings.reject! { |s| s.provider != input[:provider] }
      end

      if input[:version]
        offerings.reject! { |s| s.version != input[:version] }
      elsif !v2?
        offerings.reject!(&:deprecated?)
      end

      # filter the offerings based on a given plan value, which will be a
      # string if the user provided it with a flag, or a ServicePlan if
      # something invoked this command with a particular plan
      if v2? && plan = input.direct(:plan)
        offerings.reject! do |s|
          if plan.is_a?(String)
            s.service_plans.none? { |p| p.name == plan.upcase }
          else
            s.service_plans.include? plan
          end
        end
      end

      until offerings.size < 2
        # cast to Array since it might be given as a Service with #invoke
        offerings = Array(input[:offering, offerings.sort_by(&:label)])
        input.forget(:offering)
      end

      if offerings.empty?
        fail "Cannot find services matching the given criteria."
      end

      offering = offerings.first

      service = client.service_instance
      service.name = input[:name, offering]

      if v2?
        service.service_plan = input[:plan, offering.service_plans]
        service.space = client.current_space
      else
        service.type = offering.type
        service.vendor = offering.label
        service.version = offering.version
        service.tier = "free"
      end

      with_progress("Creating service #{c(service.name, :name)}") do
        service.create!
      end

      if app = input[:app]
        invoke :bind_service, :service => service, :app => app
      end

      service
    end

    private

    def ask_offering(offerings)
      [ask("What kind?", :choices => offerings.sort_by(&:label),
           :display => proc { |s|
              str = "#{c(s.label, :name)} #{s.version}"
              if s.provider != "core"
                str << ", via #{s.provider}"
              end
              str
           },
           :complete => proc { |s| "#{s.label} #{s.version}" })]
    end

    def ask_name(offering)
      random = sprintf("%x", rand(1000000))
      ask "Name?", :default => "#{offering.label}-#{random}"
    end

    def ask_plan(plans)
      ask "Which plan?", :choices => plans.sort_by(&:name),
        :display => proc { |p| "#{p.name}: #{p.description}" },
        :complete => proc(&:name)
    end
  end
end
