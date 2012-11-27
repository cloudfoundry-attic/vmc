require "vmc/cli/app/base"

module VMC::App
  class Routes < Base
    desc "Add a URL mapping for an app"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to add the URL to",
      :from_given => by_name("app")
    input :url, :argument => true,
      :desc => "URL to map to the application"
    def map
      app = input[:app]

      simple = input[:url].sub(/^https?:\/\/(.*)\/?/i, '\1')

      if v2?
        host, domain_name = simple.split(".", 2)

        domain =
          client.current_space.domain_by_name(domain_name, :depth => 0)

        fail "Invalid domain '#{domain_name}'" unless domain

        route = client.routes_by_host(host, :depth => 0).find do |r|
          r.domain == domain
        end

        unless route
          route = client.route

          with_progress("Creating route #{c(simple, :name)}") do
            route.host = host
            route.domain = domain
            route.space = app.space
            route.create!
          end
        end

        with_progress("Binding #{c(simple, :name)} to #{c(app.name, :name)}") do
          app.add_route(route)
        end
      else
        with_progress("Updating #{c(app.name, :name)}") do
          app.urls << simple
          app.update!
        end
      end
    end


    desc "Remove a URL mapping from an app"
    group :apps, :info, :hidden => true
    input :app, :argument => true,
      :desc => "Application to remove the URL from",
      :from_given => by_name("app")
    input(:url, :argument => true, :desc => "URL to unmap") { |choices|
      ask("Which URL?", :choices => choices)
    }
    def unmap
      app = input[:app]
      url = input[:url, app.urls]

      simple = url.sub(/^https?:\/\/(.*)\/?/i, '\1')

      if v2?
        host, domain_name = simple.split(".", 2)

        domain =
          client.current_space.domain_by_name(domain_name, :depth => 0)

        fail "Invalid domain '#{domain_name}'" unless domain

        route = app.routes_by_host(host, :depth => 0).find do |r|
          r.domain == domain
        end

        fail "Invalid route '#{simple}'" unless route

        with_progress("Removing route #{c(simple, :name)}") do
          app.remove_route(route)
        end
      else
        with_progress("Updating #{c(app.name, :name)}") do |s|
          unless app.urls.delete(simple)
            s.fail do
              err "URL #{url} is not mapped to this application."
              return
            end
          end

          app.update!
        end
      end
    end
  end
end
