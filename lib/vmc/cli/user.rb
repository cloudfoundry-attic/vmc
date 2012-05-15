require "vmc/cli/command"

module VMC
  class User < Command
    desc "create [EMAIL]", "Create a user"
    flag(:email) {
      ask("Email")
    }
    flag(:password) {
      ask("Password", :echo => "*", :forget => true)
    }
    flag(:verify) {
      ask("Verify Password", :echo => "*", :forget => true)
    }
    def create(email = nil)
      email ||= input(:email)
      password = input(:password)
      verify = input(:verify)

      if password != verify
        err "Passwords don't match."
        return
      end

      with_progress("Creating user") do
        client.register(email, password)
      end
    end

    desc "delete [EMAIL]", "Delete a user"
    flag(:really) { |email|
      force? || ask("Really delete user #{c(email, :blue)}?", :default => false)
    }
    def delete(email)
      return unless input(:really, email)

      with_progress("Deleting #{c(email, :blue)}") do
        client.user(email).delete!
      end
    ensure
      forget(:really)
    end

    desc "passwd [EMAIL]", "Update a user's password"
    flag(:email) {
      ask("Email")
    }
    flag(:password) {
      ask("Password", :echo => "*", :forget => true)
    }
    flag(:verify) {
      ask("Verify Password", :echo => "*", :forget => true)
    }
    def passwd(email = nil)
      email ||= input(:email)
      password = input(:password)
      verify = input(:verify)

      if password != verify
        err "Passwords don't match."
        return
      end

      with_progress("Changing password") do
        user = client.user(email)
        user.password = password
        user.update!
      end
    end
  end
end
