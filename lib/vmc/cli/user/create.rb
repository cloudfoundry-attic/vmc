require "vmc/cli/user/base"

module VMC::User
  class Create < Base
    desc "Create a user"
    group :admin, :user, :hidden => true
    input :email, :desc => "User email", :argument => :optional
    input :password, :desc => "User password"
    input :verify, :desc => "Repeat password"
    def create_user
      email = input[:email]
      password = input[:password]

      if !force? && password != input[:verify]
        fail "Passwords don't match."
      end

      with_progress("Creating user") do
        client.register(email, password)
      end
    end

    alias_command :add_user, :create_user

    private

    def ask_email
      ask("Email")
    end

    def ask_password
      ask("Password", :echo => "*", :forget => true)
    end

    def ask_verify
      ask("Verify Password", :echo => "*", :forget => true)
    end
  end
end
