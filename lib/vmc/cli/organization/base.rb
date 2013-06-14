require "vmc/cli/v2_check_cli"

module VMC
  module Organization
    class Base < V2CheckCLI
      def precondition
        super
        check_target
        check_logged_in

        fail "This command is v2-only." unless v2?
      end
    end
  end
end
