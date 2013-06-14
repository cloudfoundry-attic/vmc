require "vmc/cli/v2_check_cli"

module VMC
  module Space
    class Base < V2CheckCLI
      def precondition
        check_target
        check_logged_in

        fail "This command is v2-only." unless v2?
      end

      def self.space_by_name
        proc { |name, org, *_|
          org.space_by_name(name) ||
            fail("Unknown space '#{name}'.")
        }
      end
    end
  end
end
