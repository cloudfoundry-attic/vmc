require "vmc/cli/domain/base"

module VMC::Domain
  class CreateDomain < Base
    desc "Create a domain"
    group :domains
    input :name, :argument => :required,
          :desc => "Domain name to create"
    input :organization, :aliases => ["--org", "-o"],
          :from_given => by_name("organization"),
          :default => proc { client.current_organization },
          :desc => "Organization to add the domain to"
    input :shared, :type => :boolean, :default => false,
          :desc => "Create a shared domain (admin-only)"

    def create_domain
      org = input[:organization]
      name = input[:name].sub(/^\*\./, "")

      domain = client.domain
      domain.name = name
      domain.owning_organization = org unless input[:shared]

      with_progress("Creating domain #{c(name, :name)}") do
        domain.create!
      end

      domain
    end
  end
end
