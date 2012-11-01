require "vmc/cli"

module VMC
  class Route < CLI
    def precondition
      super
      fail "This command is v2-only." unless v2?
    end


    desc "List routes in a space"
    group :routes
    def routes
      routes =
        with_progress("Getting routes") do
          client.routes
        end

      line unless quiet?

      table(
        %w{host domain},
        routes.sort_by { |r| "#{r.domain.name} #{r.host}" }.collect { |r|
          [ c(r.host, :name),
            r.domain.name
          ]
        })
    end


    desc "Delete a route"
    group :routes
    input(:route, :argument => :optional,
          :from_given => find_by_name("route"),
          :desc => "URL to map to the application") { |routes|
      ask "Which route?", :choices => routes.sort_by(&:name),
        :display => proc(&:name)
    }
    input(:really, :type => :boolean, :forget => true,
          :default => proc { force? || interact }) { |name, color|
      ask("Really delete #{c(name, color)}?", :default => false)
    }
    input :all, :type => :boolean, :default => false,
      :desc => "Delete all routes"
    def delete_route
      if input[:all]
        return unless input[:really, "ALL ROUTES", :bad]

        client.routes.each do |r|
          invoke :delete_route, :route => r, :really => true
        end

        return
      end

      routes = client.routes
      fail "No routes." if routes.empty?

      route = input[:route, client.routes]

      return unless input[:really, route.name, :name]

      with_progress("Deleting route #{c(route.name, :name)}") do
        route.delete!
      end
    end


    desc "Create a route"
    group :routes
    input :url, :argument => :optional,
      :desc => "Full route in URL form"
    input(:host, :desc => "Host name") {
      ask "Host name?"
    }
    input(:domain, :desc => "Domain to add the route to",
          :from_given => find_by_name("domain")) { |domains|
      ask "Which domain?", :choices => domains,
        :display => proc(&:name)
    }
    def create_route
      if url = input[:url]
        host, domain_name = url.split(".", 2)
        return invoke :create_route, {}, :host => host, :domain => domain_name
      end

      domain = input[:domain, client.current_organization.domains]
      host = input[:host]

      route = client.route
      route.host = host
      route.domain = domain
      route.organization = client.current_organization

      with_progress("Creating route #{c("#{host}.#{domain.name}", :name)}") do
        route.create!
      end
    rescue CFoundry::APIError => e
      line c(e.description, :error)
      line
      self.input = input.without(:host)
      retry
    end
  end
end
