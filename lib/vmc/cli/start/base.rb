require "vmc/cli"

module VMC
  module Start
    class Base < CLI
      # Make sure we only show the target once
      @@displayed_target = false

      def displayed_target?
        @@displayed_target
      end


      # These commands don't require authentication.
      def precondition; end

      private

      def show_context
        return if quiet? || displayed_target?

        display_target

        line

        @@displayed_target = true
      end

      def display_target
        if quiet?
          line client.target
        else
          line "target: #{c(client.target, :name)}"
        end
      end

      def select_org_and_space(input, info)
        changed_org = false

        if input.given?(:organization) || !org_valid?(info[:organization])
          orgs = client.organizations
          fail "No organizations!" if orgs.empty?

          if orgs.size == 1 && !input.given?(:organization)
            org = orgs.first
          else
            org = input[:organization, orgs.sort_by(&:name)]
          end

          with_progress("Switching to organization #{c(org.name, :name)}") do
            info[:organization] = org.guid
            changed_org = true
          end
        else
          org = client.current_organization
        end

        # switching org means switching space
        if changed_org || input.given?(:space) || !space_valid?(info[:space])
          spaces = org.spaces

          if spaces.empty?
            if changed_org
              line c("There are no spaces in #{b(org.name)}.", :warning)
              line "You may want to create one with #{c("create-space", :good)}."
              return
            else
              fail "No spaces!"
            end
          end

          if spaces.size == 1 && !input.given?(:space)
            space = spaces.first
          else
            line if changed_org && input.interactive?(:organization)
            space = input[:space, spaces.sort_by(&:name)]
          end

          with_progress("Switching to space #{c(space.name, :name)}") do
            info[:space] = space.guid
          end
        end
      end

      def org_valid?(guid, user = client.current_user)
        return false unless guid
        client.organization(guid).users.include? user
      rescue CFoundry::APIError
        false
      end

      def space_valid?(guid, user = client.current_user)
        return false unless guid
        client.space(guid).developers.include? user
      rescue CFoundry::APIError
        false
      end
    end
  end
end
