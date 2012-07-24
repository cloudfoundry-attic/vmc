require "vmc/cli"

module VMC
  class User < CLI
    desc "List all users"
    group :admin, :hidden => true
    def users(input)
      users =
        with_progress("Getting users") do
          client.users
        end

      spaced(users) do |u|
        display_user(u)
      end
    end


    desc "Create a user"
    group :admin, :user, :hidden => true
    input(:email, :argument => true, :desc => "User email") {
      ask("Email")
    }
    input(:password, :desc => "User password") {
      ask("Password", :echo => "*", :forget => true)
    }
    input(:verify, :desc => "Repeat password") {
      ask("Verify Password", :echo => "*", :forget => true)
    }
    def create_user(input)
      email = input[:email]
      password = input[:password]

      if !force? && password != input[:verify]
        fail "Passwords don't match."
      end

      with_progress("Creating user") do
        client.register(email, password)
      end
    end

    alias_command :create_user, :add_user


    desc "Delete a user"
    group :admin, :user, :hidden => true
    input :email, :argument => true, :desc => "User to delete"
    input(:really, :type => :boolean, :forget => true) { |email|
      force? || ask("Really delete user #{c(email, :name)}?", :default => false)
    }
    def delete_user(input)
      return unless input[:really, email]

      with_progress("Deleting #{c(email, :name)}") do
        client.user(email).delete!
      end
    end


    desc "Update a user's password"
    group :admin, :user, :hidden => true
    input(:email, :argument => true, :desc => "User to update") {
      ask("Email")
    }
    input(:password, :desc => "New password") {
      ask("Password", :echo => "*", :forget => true)
    }
    input(:verify, :desc => "Repeat new password") {
      ask("Verify Password", :echo => "*", :forget => true)
    }
    def passwd(input)
      email = input[:email]
      password = input[:password]
      verify = input[:verify]

      if password != verify
        fail "Passwords don't match."
      end

      with_progress("Changing password") do
        user = client.user(email)
        user.password = password
        user.update!
      end
    end

    private

    def display_user(u)
      if quiet?
        puts u.email
      else
        line "#{c(u.email, :name)}:"

        indented do
          line "admin?: #{c(u.admin?, u.admin? ? :yes : :no)}"
        end
      end
    end
  end
end
