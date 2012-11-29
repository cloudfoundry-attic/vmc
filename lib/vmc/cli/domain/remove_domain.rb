require "vmc/cli/domain/base"

module VMC::Domain
  class RemoveDomain < Base
    desc "Remove a domain from a space"
    group :domains
    input(:domain, :argument => :optional,
          :from_given => by_name("domain"),
          :desc => "Domain to add") { |space|
      ask "Which domain?", :choices => space.domains,
          :display => proc(&:name)
    }
    input :space, :from_given => by_name("space"),
          :default => proc { client.current_space },
          :desc => "Space to add the domain to"

    def remove_domain
      space = input[:space]
      domain = input[:domain, space]

      with_progress("Removing #{c(domain.name, :name)} from #{c(space.name, :name)}") do
        space.remove_domain(domain)
      end
    end
  end
end
