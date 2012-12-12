require "vmc/cli/route/base"

module VMC::Route
  class CreateRoute < Base
    desc "Create a route"
    group :routes
    input :url, :desc => "Full route in URL form", :argument => :optional
    input :host, :desc => "Host name"
    input :domain, :desc => "Domain to add the route to",
          :from_given => by_name(:domain)
    def create_route
      if url = input[:url]
        host, domain_name = url.split(".", 2)
        return invoke :create_route, {}, :host => host, :domain => domain_name
      end

      domain = input[:domain]
      host = input[:host]

      route = client.route
      route.host = host
      route.domain = domain
      route.space = client.current_space

      with_progress("Creating route #{c("#{host}.#{domain.name}", :name)}") do
        route.create!
      end
    rescue CFoundry::RouteHostTaken => e
      line c(e.description, :error)
      line
      input.forget(:host)
      retry
    end

    private

    def ask_host
      ask("Host name?")
    end

    def ask_domain
      domains = client.current_organization.domains
      fail "No domains!" if domains.empty?

      ask "Which domain?", :choices => domains,
          :display => proc(&:name)
    end
  end
end
