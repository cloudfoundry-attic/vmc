require "vmc/cli"

module VMC
  module Organization
    class Base < CLI
      def precondition
        check_target
        check_logged_in

        fail "This command is v2-only." unless v2?
      end
    end
  end
end
