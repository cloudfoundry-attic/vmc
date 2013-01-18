require "vmc/cli/user/base"

module VMC::User
  class Passwd < Base
    desc "Update a user's password"
    group :admin, :user, :hidden => true
    input :user, :desc => "User to update", :argument => :optional,
          :default => proc { client.current_user },
          :from_given => proc { |email|
            if v2? && client.current_user.email != email
              fail "You can only change your own password on V2."
            else
              client.user(email)
            end
          }
    input :password, :desc => "Current password"
    input :new_password, :desc => "New password"
    input :verify, :desc => "Repeat new password"
    def passwd
      user = input[:user]
      password = input[:password] if v2?
      new_password = input[:new_password]

      validate_password! new_password

      with_progress("Changing password") do
        if v2?
          user.change_password!(new_password, password)
        else
          user.password = new_password
          user.update!
        end
      end
    end

    private

    def ask_password
      ask("Current Password", :echo => "*", :forget => true)
    end

    def ask_new_password
      ask("New Password", :echo => "*", :forget => true)
    end

    def ask_verify
      ask("Verify Password", :echo => "*", :forget => true)
    end
  end
end
