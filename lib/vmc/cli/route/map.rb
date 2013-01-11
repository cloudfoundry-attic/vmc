require "vmc/cli/route/base"

module VMC::Route
  class Map < Base
    def precondition; end

    desc "Add a URL mapping"
    group :apps, :info, :hidden => true
    input :url, :desc => "URL to map", :argument => true
    input :app, :desc => "Application to add the URL to", :argument => :optional,
          :from_given => by_name(:app)
    input :space, :desc => "Space to add the URL to",
          :from_given => by_name(:space)
    def map
      if input.has?(:space)
        space = input[:space]
      else
        app = input[:app]
        space = app.space if v2?
      end

      url = input[:url].sub(/^https?:\/\/(.*)\/?/i, '\1')

      if v2?
        host, domain_name = url.split(".", 2)
        domain = find_domain(space, domain_name)
        route = find_or_create_route(domain, host, space)
        bind_route(route, app) if app
      else
        with_progress("Updating #{c(app.name, :name)}") do
          app.urls << url
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

      with_progress("Creating route #{c(route.name, :name)}") { route.create! }

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
