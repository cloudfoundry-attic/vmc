require "vmc/cli/domain/base"

module VMC::Domain
  class Map < Base
    desc "Map a domain to an organization or space"
    group :domains
    input :name, :desc => "Domain to map", :argument => :required
    input :organization, :desc => "Organization to map the domain to",
          :aliases => %w{--org -o},
          :default => proc { client.current_organization },
          :from_given => by_name(:organization)
    input :space, :desc => "Space to map the domain to",
          :default => proc { client.current_space },
          :from_given => by_name(:space)
    input :shared, :desc => "Create a shared domain", :default => false
    def map_domain
      domain = client.domain_by_name(input[:name])

      given_org = input.has?(:organization)
      given_space = input.has?(:space)

      org = input[:organization]
      space = input[:space]

      given_space = true unless given_org || given_space

      unless domain
        domain = client.domain
        domain.name = input[:name]
        domain.owning_organization = org unless input[:shared]

        with_progress("Creating domain #{c(domain.name, :name)}") do
          domain.create!
          org.add_domain(domain) if org && !given_org && !given_space
        end
      end

      if given_space
        add_domain(domain, space.organization)
        add_domain(domain, space)
      elsif given_org
        add_domain(domain, org)
      end
    end

    private

    def add_domain(domain, target)
      with_progress("Mapping #{c(domain.name, :name)} to #{c(target.name, :name)}") do
        target.add_domain(domain)
      end
    end
  end
end
