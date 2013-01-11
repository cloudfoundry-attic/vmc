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

        if input.has?(:organization) || !org_valid?(info[:organization])
          org = input[:organization]
          return unless org

          with_progress("Switching to organization #{c(org.name, :name)}") do
            info[:organization] = org.guid
            changed_org = true
          end
        else
          org = client.current_organization
        end

        # switching org means switching space
        if changed_org || input.has?(:space) || !space_valid?(info[:space])
          line if changed_org && !quiet?

          space = input[:space, org]
          return unless space

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
