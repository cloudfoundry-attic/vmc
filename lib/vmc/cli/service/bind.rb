require "vmc/detect"

require "vmc/cli/service/base"

module VMC::Service
  class Bind < Base
    desc "Bind a service to an application"
    group :services, :manage
    input :service, :desc => "Service to bind", :argument => :optional,
          :from_given => by_name(:service_instance, "service")
    input :app, :desc => "Application to bind to", :argument => :optional,
          :from_given => by_name(:app)
    def bind_service
      app = input[:app]
      service = input[:service, app]

      with_progress(
          "Binding #{c(service.name, :name)} to #{c(app.name, :name)}") do |s|
        if app.binds?(service)
          s.skip do
            err "App #{b(app.name)} already binds #{b(service.name)}."
          end
        else
          app.bind(service)
        end
      end
    end

    private

    def ask_service(app)
      services = client.service_instances
      fail "No services." if services.empty?

      ask "Which service?", :choices => services - app.services,
        :display => proc(&:name)
    end

    def ask_app
      ask "Which application?", :choices => client.apps,
        :display => proc(&:name)
    end
  end
end
