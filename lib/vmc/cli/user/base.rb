require "vmc/cli/v2_check_cli"

module VMC
  module User
    class Base < V2CheckCLI
      def precondition
        check_logged_in
      end

      private

      def validate_password!(password)
        validate_password_verified!(password)
        validate_password_strength!(password)
      end

      def validate_password_verified!(password)
        fail "Passwords do not match." unless force? || password == input[:verify]
      end

      def validate_password_strength!(password)
        strength = client.base.password_score(password)
        msg = "Your password strength is: #{strength}"
        fail msg if strength == :weak
        line msg
      end
    end
  end
end
