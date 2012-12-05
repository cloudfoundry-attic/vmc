require "vmc/detect"

require "vmc/cli/service/base"

module VMC::Service
  class Service < Base
    desc "Show service instance information"
    group :services
    input :instance, :argument => :required,
      :from_given => by_name("service instance", :service_instance),
      :desc => "Service instance to show"
    def service
      display_service_instance(input[:instance])
    end

    private

    def display_service_instance(i)
      if quiet?
        line i.name
      elsif v2?
        plan = i.service_plan
        service = plan.service

        apps = i.service_bindings.collect { |b|
          c(b.app.name, :name)
        }.join(", ")

        line "#{c(i.name, :name)}: #{service.label} #{service.version}"

        indented do
          line "provider: #{c(service.provider, :name)}"
          line "bound to: #{apps}" unless apps.empty?
          line "plan: #{c(plan.name, :name)}"

          indented do
            line "description: #{plan.description}"
          end
        end
      else
        line "#{c(i.name, :name)}: #{i.vendor} #{i.version}"
      end
    end
  end
end
