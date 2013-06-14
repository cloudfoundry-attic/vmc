require "vmc/cli/v2_check_cli"

module VMC
  module Domain
    class Base < V2CheckCLI
      def precondition
        super
        fail "This command is v2-only." unless v2?
      end
    end
  end
end
