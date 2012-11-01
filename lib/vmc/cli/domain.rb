require "vmc/cli"

module VMC
  class Domain < CLI
    def precondition
      super
      fail "This command is v2-only." unless v2?
    end


    desc "List domains in a space"
    group :domains
    input :organization, :argument => :optional, :aliases => ["--org", "-o"],
      :from_given => by_name("organization"),
      :desc => "Organization to delete the domain from"
    def domains
      target = input[:organization] || client

      domains =
        with_progress("Getting domains") do
          target.domains
        end

      line unless quiet?

      table(
        %w{name wildcard? owner},
        domains.sort_by(&:name).collect { |r|
          [ c(r.name, :name),
            c(r.wildcard, r.wildcard ? :yes : :no),
            if org = r.owning_organization
              c(org.name, :name)
            else
              d("none")
            end
          ]
        })
    end


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


    desc "Create a domain"
    group :domains
    input :name, :argument => :required,
      :desc => "Domain name to create (*.foo.com for wildcard)"
    input :organization, :aliases => ["--org", "-o"],
      :from_given => by_name("organization"),
      :default => proc { client.current_organization },
      :desc => "Organization to add the domain to"
    def create_domain
      org = input[:organization]
      name = input[:name]
      wildcard = false

      # *.foo.com for wildcard
      if name =~ /^\*\.(.+)$/
        name = $1
        wildcard = true
      end

      domain = client.domain
      domain.name = name
      domain.wildcard = wildcard
      domain.owning_organization = org

      with_progress("Creating domain #{c(name, :name)}") do
        domain.create!
        org.add_domain(domain) if org
      end
    end


    desc "Add a domain to a space"
    group :domains
    input(:domain, :argument => :optional,
          :from_given => by_name("domain"),
          :desc => "Domain to add") {
      ask "Which domain?", :choices => client.current_organization.domains,
        :display => proc(&:name)
    }
    input :space, :from_given => by_name("space"),
      :default => proc { client.current_space },
      :desc => "Space to add the domain to"
    def add_domain
      space = input[:space]
      domain = input[:domain]

      with_progress("Adding #{c(domain.name, :name)} to #{c(space.name, :name)}") do
        space.add_domain(domain)
      end
    end


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
        space.add_domain(domain)
      end
    end
  end
end
