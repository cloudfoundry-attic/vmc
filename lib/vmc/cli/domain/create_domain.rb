require "vmc/cli/domain/base"

module VMC::Domain
  class CreateDomain < Base
    desc "Create a domain"
    group :domains
    input :name, :desc => "Domain name to create", :argument => :required
    input :organization, :desc => "Organization to add the domain to",
          :aliases => %w{--org -o},
          :default => proc { client.current_organization },
          :from_given => by_name(:organization)
    input :shared, :desc => "Create a shared domain", :default => false
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
