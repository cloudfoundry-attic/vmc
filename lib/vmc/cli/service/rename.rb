require "vmc/detect"

require "vmc/cli/service/base"

module VMC::Service
  class Rename < Base
    desc "Rename a service"
    group :services, :manage, :hidden => true
    input(:service, :aliases => ["--org", "-o"],
          :argument => :optional, :desc => "service to rename",
          :from_given => by_name("service", :service_instance)) {
      services = client.service_instances
      fail "No services." if services.empty?

      ask("Rename which service?", :choices => services.sort_by(&:name),
          :display => proc(&:name))
    }
    input(:name, :argument => :optional, :desc => "New service name") {
      ask("New name")
    }
    def rename_service
      service = input[:service]
      name = input[:name]

      service.name = name

      with_progress("Renaming to #{c(name, :name)}") do
        service.update!
      end
    end
  end
end
