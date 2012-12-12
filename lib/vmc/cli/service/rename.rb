require "vmc/cli/service/base"

module VMC::Service
  class Rename < Base
    desc "Rename a service"
    group :services, :manage, :hidden => true
    input :service, :desc => "Service to rename", :argument => :optional,
          :from_given => by_name(:service_instance, :service)
    input :name, :desc => "New service name", :argument => :optional
    def rename_service
      service = input[:service]
      name = input[:name]

      service.name = name

      with_progress("Renaming to #{c(name, :name)}") do
        service.update!
      end
    end

    private

    def ask_service
      services = client.service_instances
      fail "No services." if services.empty?

      ask("Rename which service?", :choices => services.sort_by(&:name),
          :display => proc(&:name))
    end

    def ask_name
      ask("New name")
    end
  end
end
