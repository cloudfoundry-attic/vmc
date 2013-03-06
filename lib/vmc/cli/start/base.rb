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

      def select_org(input, info)
        if input.has?(:organization) || !org_valid?(info[:organization])
          org = input[:organization]
          if org
            with_progress("Switching to organization #{c(org.name, :name)}") {}
            client.current_organization = org
          end
          info[:organization] = org ? org.guid : nil
          !!org
        else
          info[:organization] = nil
          client.current_organization = nil
          false
        end
      end

      def select_space(input, info, changed_org)
        if input.has?(:space) || !space_valid?(info[:space])
          line if changed_org && !quiet?
          space = input[:space, client.current_organization]
          if space
            with_progress("Switching to space #{c(space.name, :name)}") {}
            client.current_space = space
          end
          info[:space] = space ? space.guid : nil
        else
          info[:space] = nil
          client.current_space = nil
        end
      end

      def select_org_and_space(input, info)
        changed_org = select_org(input, info)
        if client.current_organization
          select_space(input, info, changed_org)
        else
          info[:space] = nil
          client.current_space = nil
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
