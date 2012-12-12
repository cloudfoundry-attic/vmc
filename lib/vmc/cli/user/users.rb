require "vmc/cli/user/base"

module VMC::User
  class Users < Base
    desc "List all users"
    group :admin, :hidden => true
    def users
      users =
        with_progress("Getting users") do
          client.users(:depth => 0)
        end

      spaced(users) do |u|
        display_user(u)
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
