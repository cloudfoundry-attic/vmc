require "vmc/detect"

require "vmc/cli/service/base"

module VMC::Service
  class Binding < Base
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
      ask "Which application?", :choices => client.apps(:depth => 2),
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
          :desc => "Service to bind") { |services|
      ask "Which service instance?", :choices => services,
        :display => proc(&:name)
    }
    input(:app, :argument => true,
          :from_given => by_name("app"),
          :desc => "Application to bind to") {
      ask "Which application?", :choices => client.apps(:depth => 2),
        :display => proc(&:name)
    }
    def unbind_service
      app = input[:app]
      instance = input[:instance, app.services]

      with_progress(
          "Unbinding #{c(instance.name, :name)} from #{c(app.name, :name)}") do
        app.unbind(instance)
      end
    end
  end
end
