require "vmc/cli"

module VMC
  class Service < CLI
    desc "List your services"
    group :services
    input :name, :desc => "Filter by name regexp"
    input :app, :desc => "Filter by bound application regexp"
    input :type, :desc => "Filter by service type regexp"
    input :vendor, :desc => "Filter by service vendor regexp"
    input :tier, :desc => "Filter by service tier regexp"
    def services(input)
      services =
        with_progress("Getting services") do
          client.services
        end

      puts "" unless simple_output?

      if services.empty? and !simple_output?
        puts "No services."
      end

      if app = input[:app]
        apps = client.apps
        services.reject! do |s|
          apps.none? { |a| a.services.include? s.name }
        end
      end

      services.each do |s|
        display_service(s) if service_matches(s, input)
      end
    end


    desc "Create a service"
    group :services, :manage
    input(:vendor, :argument => true) { |choices|
      ask "What kind?", :choices => choices
    }
    input(:name, :argument => true) { |vendor|
      random = sprintf("%x", rand(1000000))
      ask "Name?", :default => "#{vendor}-#{random}"
    }
    input(:version) { |choices|
      ask "Which version?", :choices => choices
    }
    def create_service(input)
      services = client.system_services

      vendor = input[:vendor, services.keys.sort]
      meta = services[vendor]

      if meta[:versions].size == 1
        version = meta[:versions].first
      else
        version = input[:version, meta[:versions]]
      end

      service = client.service(input[:name, meta[:vendor]])
      service.type = meta[:type]
      service.vendor = meta[:vendor]
      service.version = version
      service.tier = "free"

      with_progress("Creating service #{c(service.name, :name)}") do
        service.create!
      end
    end

    desc "Bind a service to an application"
    group :services, :manage
    input(:name, :argument => true) { |choices|
      ask "Which service?", :choices => choices
    }
    input(:app, :argument => true) { |choices|
      ask "Which application?", :choices => choices
    }
    def bind_service(input)
      name = input[:name, client.services.collect(&:name)]
      appname = input[:app, client.apps.collect(&:name)]

      with_progress("Binding #{c(name, :name)} to #{c(appname, :name)}") do
        client.app(appname).bind(name)
      end
    end


    desc "Unbind a service from an application"
    group :services, :manage
    input(:name, :argument => true) { |choices|
      ask "Which service?", :choices => choices
    }
    input(:app, :argument => true) { |choices|
      ask "Which application?", :choices => choices
    }
    def unbind_service(input)
      appname = input[:app, client.apps.collect(&:name)]

      app = client.app(appname)
      name = input[:name, app.services]

      with_progress("Unbinding #{c(name, :name)} from #{c(appname, :name)}") do
        app.unbind(name)
      end
    end


    desc "Delete a service"
    group :services, :manage
    input(:name, :argument => true) { |choices|
      ask "Delete which service?", :choices => choices
    }
    input(:really, :type => :boolean) { |name, color|
      force? || ask("Really delete #{c(name, color)}?", :default => false)
    }
    input(:all, :default => false)
    def delete_service(input)
      if input[:all]
        return unless input[:really, "ALL SERVICES", :bad]

        with_progress("Deleting all services") do
          client.services.collect(&:delete!)
        end

        return
      end

      if input.given? :name
        name = input[:name]
      else
        services = client.services
        fail "No services." if services.empty?

        name = input[:name, services.collect(&:name)]
      end

      return unless input[:really, name, :name]

      with_progress("Deleting #{c(name, :name)}") do
        client.service(name).delete!
      end
    end

    private

    def service_matches(s, options)
      if name = options[:name]
        return false if s.name !~ /#{name}/
      end

      if type = options[:type]
        return false if s.type !~ /#{type}/
      end

      if vendor = options[:vendor]
        return false if s.vendor !~ /#{vendor}/
      end

      if tier = options[:tier]
        return false if s.tier !~ /#{tier}/
      end

      true
    end

    def display_service(s)
      if simple_output?
        puts s.name
      else
        puts "#{c(s.name, :name)}: #{s.vendor} v#{s.version}"
      end
    end
  end
end
