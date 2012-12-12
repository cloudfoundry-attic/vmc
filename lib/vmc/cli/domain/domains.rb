require "vmc/cli/domain/base"

module VMC::Domain
  class Domains < Base
    desc "List domains in a space"
    group :domains
    input :space, :desc => "Space to list the domains from",
          :argument => :optional, :default => proc { client.current_space },
          :from_given => by_name(:space)
    input :all, :desc => "List all domains", :default => false
    def domains
      space = input[:space]

      domains =
        if input[:all]
          with_progress("Getting all domains") do
            client.domains
          end
        else
          with_progress("Getting domains in #{c(space.name, :name)}") do
            space.domains
          end
        end

      line unless quiet?

      table(
        %w{name owner},
        domains.sort_by(&:name).collect { |r|
          [c(r.name, :name),
           if org = r.owning_organization
             c(org.name, :name)
           else
             d("none")
           end
          ]
        })
    end
  end
end
