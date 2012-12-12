require "vmc/cli/user/base"

module VMC::User
  class Delete < Base
    desc "Delete a user"
    group :admin, :user, :hidden => true
    input :email, :desc => "User to delete", :argument => true
    input :really, :type => :boolean, :forget => true, :hidden => true,
          :default => proc { force? || interact }
    def delete_user
      email = input[:email]
      return unless input[:really, email]

      with_progress("Deleting #{c(email, :name)}") do
        client.user(email).delete!
      end
    end

    private

    def ask_really(email)
      ask("Really delete user #{c(email, :name)}?", :default => false)
    end
  end
end
