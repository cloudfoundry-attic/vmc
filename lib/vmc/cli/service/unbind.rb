require "vmc/detect"

require "vmc/cli/service/base"

module VMC::Service
  class Unbind < Base
    desc "Unbind a service from an application"
    group :services, :manage
    input :service, :desc => "Service to unbind", :argument => :optional,
          :from_given => by_name(:service_instance, :service)
    input :app, :desc => "Application to unbind from", :argument => :optional,
          :from_given => by_name(:app)
    def unbind_service
      app = input[:app]
      service = input[:service, app]

      with_progress(
          "Unbinding #{c(service.name, :name)} from #{c(app.name, :name)}") do
        app.unbind(service)
      end
    end

    private

    def ask_service(app)
      services = app.services
      fail "No bound services." if services.empty?

      ask "Which service?", :choices => services,
        :display => proc(&:name)
    end

    def ask_app
      ask "Which application?", :choices => client.apps,
        :display => proc(&:name)
    end
  end
end
