module VMC::Cli

  class CliError < StandardError
    def self.error_code(code = nil)
      define_method(:error_code) { code }
    end
  end

  class UnknownCommand       < CliError; error_code(100); end
  class TargetMissing        < CliError; error_code(102); end
  class TargetInaccessible   < CliError; error_code(103); end

  class TargetError          < CliError; error_code(201); end
  class AuthError            < TargetError; error_code(202); end

  class CliExit              < CliError; error_code(400); end
  class GracefulExit         < CliExit;  error_code(401); end

end
