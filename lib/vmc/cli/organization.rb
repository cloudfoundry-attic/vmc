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
    input(:organization, :aliases => ["--org", "-o"],
          :argument => :optional, :from_given => by_name("organization"),
          :desc => "Organization to show") {
      client.current_organization
    }
    input :full, :type => :boolean,
      :desc => "Show full information for appspaces"
    def org(input)
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
    def orgs(input)
      orgs =
        with_progress("Getting organizations") do
          client.organizations
        end

      line unless quiet?

      orgs.each do |o|
        line c(o.name, :name)
      end
    end

    private

    def name_list(xs)
      if xs.empty?
        d("none")
      else
        xs.collect { |x| c(x.name, :name) }.join(", ")
      end
    end
  end
end
