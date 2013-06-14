require "vmc/cli/v2_check_cli"

module VMC
  class V2CheckCLI < CLI
    def precondition
      fail_on_v2
    end

    def fail_on_v2
      if v2?
        fail "You are targeting a version 2 instance of Cloud Foundry: you must use the 'cf' command line client (which you can get with 'gem install cf')."
      end
    end
  end
end

