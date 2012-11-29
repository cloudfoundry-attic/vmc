require "vmc/cli/route/base"

module VMC::Route
  class DeleteRoute < Base
    desc "Delete a route"
    group :routes
    input(:route, :argument => :optional,
          :from_given => find_by_name("route"),
          :desc => "Route to delete") { |routes|
      ask "Which route?", :choices => routes.sort_by(&:name),
        :display => proc(&:name)
    }
    input(:really, :type => :boolean, :forget => true, :hidden => true,
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
  end
end
