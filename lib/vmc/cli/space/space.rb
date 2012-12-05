require "vmc/detect"

require "vmc/cli/space/base"

module VMC::Space
  class Space < Base
    desc "Show space information"
    group :spaces
    input :organization, :aliases => ["--org", "-o"],
      :from_given => by_name("organization"),
      :default => proc { client.current_organization },
      :desc => "Space's organization"
    input :space, :argument => :optional,
      :from_given => space_by_name,
      :default => proc { client.current_space },
      :desc => "Space to show"
    input :full, :type => :boolean,
      :desc => "Show full information for apps, service instances, etc."
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
          spaced(space.service_instances(:depth => 2)) do |i|
            indented do
              invoke :service, :instance => i
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
