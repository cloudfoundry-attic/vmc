require "vmc/cli/route/base"

module VMC::Route
  class Routes < Base
    desc "List routes in a space"
    group :routes

    def routes
      # TODO: scope to space once space.routes is possible
      routes =
          with_progress("Getting routes") do
            client.routes
          end

      line unless quiet?

      table(
          %w{host domain},
          routes.sort_by { |r| "#{r.domain.name} #{r.host}" }.collect { |r|
            [c(r.host, :name),
             r.domain.name
            ]
          })
    end
  end
end
