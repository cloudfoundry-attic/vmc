require "vmc/cli/command"

module VMC
  class Service < Command
    desc "create", "Create a service"
    group :services, :manage
    flag(:vendor) { |choices|
      ask "What kind?", :choices => choices
    }
    flag(:version) { |choices|
      ask "Which version?", :choices => choices
    }
    flag(:name) { |vendor|
      random = sprintf("%x", rand(1000000))
      ask "Name?", :default => "#{vendor}-#{random}"
    }
    def create
      services = client.system_services

      vendor = input(:vendor, services.keys)
      meta = services[vendor]

      if meta[:versions].size == 1
        version = meta[:versions].first
      else
        version = input(:version, meta[:versions])
      end

      service = client.service(input(:name, meta[:vendor]))
      service.type = meta[:type]
      service.vendor = meta[:vendor]
      service.version = version
      service.tier = "free"

      with_progress("Creating service #{c(service.name, :blue)}") do
        service.create!
      end
    end

    desc "bind", "Bind a service to an application"
    group :services, :manage
    flag(:name) { |choices|
      ask "Which service?", :choices => choices
    }
    flag(:app) { |choices|
      ask "Which application?", :choices => choices
    }
    def bind(name = nil, appname = nil)
      name ||= input(:name, client.services.collect(&:name))
      appname ||= input(:app, client.apps.collect(&:name))

      with_progress("Binding #{c(name, :blue)} to #{c(appname, :blue)}") do
        client.app(appname).bind(name)
      end
    end

    desc "unbind", "Unbind a service from an application"
    group :services, :manage
    flag(:name) { |choices|
      ask "Which service?", :choices => choices
    }
    flag(:app) { |choices|
      ask "Which application?", :choices => choices
    }
    def unbind(name = nil, appname = nil)
      appname ||= input(:app, client.apps.collect(&:name))

      app = client.app(appname)
      name ||= input(:name, app.services)

      with_progress("Unbinding #{c(name, :blue)} from #{c(appname, :blue)}") do
        app.unbind(name)
      end
    end

    desc "delete", "Delete a service"
    group :services, :manage
    flag(:really) { |name, color|
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    flag(:name) { |choices|
      ask "Delete which service?", :choices => choices
    }
    flag(:all, :default => false)
    def delete(name = nil)
      if input(:all)
        return unless input(:really, "ALL SERVICES", :red)

        with_progress("Deleting all services") do
          client.services.collect(&:delete!)
        end

        return
      end

      unless name
        services = client.services
        fail "No services." if services.empty?

        name = input(:name, services.collect(&:name))
      end

      return unless input(:really, name, :blue)

      with_progress("Deleting #{c(name, :blue)}") do
        client.service(name).delete!
      end
    ensure
      forget(:really)
    end
  end
end
