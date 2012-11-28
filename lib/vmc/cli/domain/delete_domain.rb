require "vmc/cli/domain/base"

module VMC::Domain
  class DeleteDomain < Base
    desc "Delete a domain"
    group :domains
    input(:domain, :argument => :optional,
          :from_given => find_by_name("domain"),
          :desc => "URL to map to the application") { |domains|
      fail "No domains." if domains.empty?

      ask "Which domain?", :choices => domains.sort_by(&:name),
          :display => proc(&:name)
    }
    input :organization, :aliases => ["--org", "-o"],
          :from_given => by_name("organization"),
          :desc => "Organization to delete the domain from"
    input(:really, :type => :boolean, :forget => true,
          :default => proc { force? || interact }) { |name, color|
      ask("Really delete #{c(name, color)}?", :default => false)
    }
    input :all, :type => :boolean, :default => false,
          :desc => "Delete all domains"

    def delete_domain
      target = input[:organization] || client

      if input[:all]
        return unless input[:really, "ALL DOMAINS", :bad]

        target.domains.each do |r|
          begin
            invoke :delete_domain, :domain => r, :really => true
          rescue CFoundry::APIError => e
            err "#{e.class}: #{e.message}"
          end
        end

        return
      end

      domain = input[:domain, target.domains]

      return unless input[:really, domain.name, :name]

      with_progress("Deleting domain #{c(domain.name, :name)}") do
        domain.delete!
      end
    end
  end
end
