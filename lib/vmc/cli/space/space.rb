require "vmc/cli/space/base"

module VMC::Space
  class Space < Base
    desc "Show space information"
    group :spaces
    input :organization, :desc => "Space's organization",
          :aliases => %w{--org -o},
          :default => proc { client.current_organization },
          :from_given => by_name(:organization)
    input :space, :desc => "Space to show", :argument => :optional,
          :default => proc { client.current_space },
          :from_given => space_by_name
    input :full, :desc => "Show full information for apps, services, etc.",
          :default => false
    def space
      org = input[:organization]
      space = input[:space, org]

      unless space
        return if quiet?
        fail "No current space."
      end

      if quiet?
        puts space.name
        return
      end

      line "#{c(space.name, :name)}:"

      indented do
        line "organization: #{c(space.organization.name, :name)}"

        if input[:full]
          line
          line "apps:"

          spaced(space.apps(:depth => 2)) do |a|
            indented do
              invoke :app, :app => a
            end
          end
        else
          line "apps: #{name_list(space.apps)}"
        end

        if input[:full]
          line
          line "services:"
          spaced(space.service_instances(:depth => 2)) do |s|
            indented do
              invoke :service, :service => s
            end
          end
        else
          line "services: #{name_list(space.service_instances)}"
        end

        line "domains: #{name_list(space.domains)}"
      end
    end
  end
end
