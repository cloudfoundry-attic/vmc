require "vmc/detect"
require "vmc/cli/start/base"

module VMC::Start
  class Register < Base
    desc "Create a user and log in"
    group :start, :hidden => true
    input(:email, :argument => true, :desc => "Desired email") {
      ask("Email")
    }
    input(:password, :desc => "Desired password") {
      ask("Password", :echo => "*", :forget => true)
    }
    input(:verify, :desc => "Repeat password") {
      ask("Confirm Password", :echo => "*", :forget => true)
    }
    input :login, :type => :boolean, :default => true,
      :desc => "Automatically log in?"
    def register
      show_context

      email = input[:email]
      password = input[:password]

      if !force? && password != input[:verify]
        fail "Passwords do not match."
      end

      with_progress("Creating user") do
        client.register(email, password)
      end

      if input[:login]
        invoke :login, :username => email, :password => password
      end
    end
  end
end
