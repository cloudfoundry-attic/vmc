require "vmc/cli"

module VMC
  class Organization < CLI
    def precondition
      super
      fail "This command is v2-only." unless v2?
    end

    def self.by_name(what, obj = what)
      proc { |name, *_|
        client.send(:"#{obj}_by_name", name) ||
          fail("Unknown #{what} '#{name}'")
      }
    end

    desc "Show organization information"
    group :organizations
    input :organization, :aliases => ["--org", "-o"],
      :argument => :optional,
      :from_given => by_name("organization"),
      :default => proc { client.current_organization },
      :desc => "Organization to show"
    input :full, :type => :boolean,
      :desc => "Show full information for spaces, domains, etc."
    def org
      org = input[:organization]

      if quiet?
        puts org.name
        return
      end

      line "#{c(org.name, :name)}:"

      indented do
        line "domains: #{name_list(org.domains)}"

        if input[:full]
          line "spaces:"

          spaced(org.spaces(2)) do |s|
            indented do
              invoke :space, :space => s
            end
          end
        else
          line "spaces: #{name_list(org.spaces)}"
        end
      end
    end


    desc "List available organizations"
    group :organizations
    input :one_line, :alias => "-l", :type => :boolean, :default => false,
      :desc => "Single-line tabular format"
    input :full, :type => :boolean, :default => false,
      :desc => "Show full information for apps, service instances, etc."
    def orgs
      orgs =
        with_progress("Getting organizations") do
          client.organizations(1)
        end

      line unless quiet?

      if input[:one_line]
        table(
          %w{name spaces domains},
          orgs.collect { |o|
            [ c(o.name, :name),
              name_list(o.spaces),
              name_list(o.domains)
            ]
          })
      else
        orgs.each do |o|
          invoke :org, :organization => o, :full => input[:full]
        end
      end
    end
  end
end
