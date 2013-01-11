require "vmc/cli/domain/base"

module VMC::Domain
  class Unmap < Base
    desc "Unmap a domain from an organization or space"
    group :domains
    input :domain, :desc => "Domain to unmap", :argument => :required,
          :from_given => by_name("domain")
    input :organization, :desc => "Organization to unmap the domain from",
          :aliases => %w{--org -o},
          :default => proc { client.current_organization },
          :from_given => by_name(:organization)
    input :space, :desc => "Space to unmap the domain from",
          :default => proc { client.current_space },
          :from_given => by_name(:space)
    input :delete, :desc => "Delete domain", :type => :boolean
    input :really, :type => :boolean, :forget => true, :hidden => true,
          :default => proc { force? || interact }
    def unmap_domain
      domain = input[:domain]

      given_org = input.has?(:organization)
      given_space = input.has?(:space)

      org = input[:organization]
      space = input[:space]

      if input[:delete]
        return unless input[:really, domain.name, :name]

        with_progress("Deleting domain #{c(domain.name, :name)}") do
          domain.delete!
        end

        return
      end

      given_space = true unless given_org || given_space

      remove_domain(domain, space) if given_space
      remove_domain(domain, org) if given_org
    end

    private

    def remove_domain(domain, target)
      with_progress("Unmapping #{c(domain.name, :name)} from #{c(target.name, :name)}") do
        target.remove_domain(domain)
      end
    end

    def ask_really(name, color)
      ask("Really delete #{c(name, color)}?", :default => false)
    end
  end
end