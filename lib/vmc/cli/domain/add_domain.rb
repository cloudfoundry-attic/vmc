require "vmc/cli/domain/base"

module VMC::Domain
  class AddDomain < Base
    desc "Add a domain to a space"
    group :domains
    input :name, :argument => :required,
          :desc => "Domain to add"
    input :space, :from_given => by_name("space"),
          :default => proc { client.current_space },
          :desc => "Space to add the domain to"

    def add_domain
      space = input[:space]
      name = input[:name].sub(/^\*\./, "")

      org = space.organization

      domain = org.domains.find { |d| d.name == name } ||
        invoke(:create_domain, :org => org, :name => name)

      with_progress("Adding #{c(domain.name, :name)} to #{c(space.name, :name)}") do
        space.add_domain(domain)
      end
    end
  end
end
