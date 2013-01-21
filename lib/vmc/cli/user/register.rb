require "vmc/cli/user/base"

module VMC::User
  class Register < Base
    def precondition; end

    desc "Create a user and log in"
    group :admin, :user, :hidden => true
    input :email, :desc => "Desired email", :argument => :optional
    input :password, :desc => "Desired password"
    input :verify, :desc => "Repeat password"
    input :login, :desc => "Automatically log in?", :default => true
    def register
      email = input[:email]
      password = input[:password]

      validate_password!(password)

      with_progress("Creating user") do
        client.register(email, password)
      end

      if input[:login]
        invoke :login, :username => email, :password => password
      end
    end

    private

    def ask_email
      ask("Email")
    end

    def ask_password
      ask("Password", :echo => "*", :forget => true)
    end

    def ask_verify
      ask("Confirm Password", :echo => "*", :forget => true)
    end
  end
end
