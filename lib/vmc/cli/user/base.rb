require "vmc/cli"

module VMC
  module User
    class Base < CLI
      def precondition
        check_logged_in
      end
    end
  end
end
