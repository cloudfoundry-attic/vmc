require "vmc/cli/route/base"

module VMC::Route
  class CreateRoute < Base
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
  end
end