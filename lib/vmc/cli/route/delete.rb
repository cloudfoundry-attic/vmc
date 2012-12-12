require "vmc/cli/route/base"

module VMC::Route
  class Delete < Base
    desc "Delete a route"
    group :routes
    input :route, :desc => "Route to delete", :argument => :optional,
          :from_given => find_by_name("route") { client.routes },
          :default => proc { force? || interact }
    input :all, :desc => "Delete all routes", :default => false
    input :really, :type => :boolean, :forget => true, :hidden => true,
          :default => proc { force? || interact }
    def delete_route
      if input[:all]
        return unless input[:really, "ALL ROUTES", :bad]

        client.routes.each do |r|
          invoke :delete_route, :route => r, :really => true
        end

        return
      end

      route = input[:route]

      return unless input[:really, route.name, :name]

      with_progress("Deleting route #{c(route.name, :name)}") do
        route.delete!
      end
    end

    private

    def ask_route
      routes = client.routes
      fail "No routes." if routes.empty?

      ask "Which route?", :choices => routes.sort_by(&:name),
        :display => proc(&:name)
    end

    def ask_really(name, color)
      ask("Really delete #{c(name, color)}?", :default => false)
    end
  end
end
