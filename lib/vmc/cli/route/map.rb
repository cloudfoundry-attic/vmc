require "vmc/cli/route/base"

module VMC::Route
  class Map < Base
    def precondition
      fail_on_v2
    end

    desc "Add a URL mapping"
    group :apps, :info, :hidden => true
    input :app, :desc => "Application to add the URL to",
          :argument => :optional, :from_given => by_name(:app)
    input :host, :desc => "Host name for the route",
          :argument => :optional, :default => ""
    input :domain, :desc => "Domain to add the route to",
          :argument => true,
          :from_given => proc { |name, space|
            if v2?
              space.domain_by_name(name) ||
                fail_unknown("domain", name)
            else
              name
            end
          }
    def map
      app = input[:app]
      space = app.space if v2?

      host = input[:host]
      domain = input[:domain, space]

      if v2?
        route = find_or_create_route(domain, host, space)
        bind_route(route, app) if app
      else
        with_progress("Updating #{c(app.name, :name)}") do
          app.urls << domain
          app.update!
        end
      end
    end

    private

    def bind_route(route, app)
      with_progress("Binding #{c(route.name, :name)} to #{c(app.name, :name)}") do
        app.add_route(route)
      end
    end

    def find_or_create_route(domain, host, space)
      find_route(domain, host) || create_route(domain, host, space)
    end

    def find_route(domain, host)
      client.routes_by_host(host, :depth => 0).find { |r| r.domain == domain }
    end

    def create_route(domain, host, space)
      route = client.route
      route.host = host
      route.domain = domain
      route.space = space

      with_progress("Creating route #{c(route.name, :name)}") do
        route.create!
      end

      route
    end

    def find_domain(space, name)
      domain = space.domain_by_name(name, :depth => 0)
      fail "Invalid domain '#{name}'" unless domain
      domain
    end

    def ask_app
      ask("Which application?", :choices => client.apps, :display => proc(&:name))
    end
  end
end
