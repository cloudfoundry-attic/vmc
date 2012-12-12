require "vmc/cli/organization/base"

module VMC::Organization
  class Org < Base
    desc "Show organization information"
    group :organizations
    input :organization, :desc => "Organization to show",
          :aliases => %w{--org -o}, :argument => :optional,
          :from_given => by_name(:organization),
          :default => proc { client.current_organization }
    input :full, :desc => "Show full information for spaces, domains, etc.",
          :default => false
    def org
      org = input[:organization]

      unless org
        return if quiet?
        fail "No current organization."
      end

      if quiet?
        puts org.name
        return
      end

      line "#{c(org.name, :name)}:"

      indented do
        line "domains: #{name_list(org.domains)}"

        if input[:full]
          line "spaces:"

          spaced(org.spaces(:depth => 2)) do |s|
            indented do
              invoke :space, :space => s
            end
          end
        else
          line "spaces: #{name_list(org.spaces)}"
        end
      end
    end
  end
end