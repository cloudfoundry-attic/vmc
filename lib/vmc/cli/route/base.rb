require "vmc/cli"

module VMC
  module Route
    class Base < CLI
      def precondition
        super
        fail "This command is v2-only." unless v2?
      end
    end
  end
end
