require "vmc/cli"

module VMC
  module Organization
    class Base < CLI
      def precondition
        check_target
        check_logged_in

        fail "This command is v2-only." unless v2?
      end

      def self.by_name(what, obj = what)
        proc { |name, *_|
          client.send(:"#{obj}_by_name", name) ||
              fail("Unknown #{what} '#{name}'")
        }
      end
    end
  end
end
