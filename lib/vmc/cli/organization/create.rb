require "vmc/cli/organization/base"

module VMC::Organization
  class Create < Base
    desc "Create an organization"
    group :organizations
    input :name, :desc => "Organization name", :argument => :optional
    input :target, :desc => "Switch to the organization after creation",
          :alias => "-t", :default => true
    input :add_self, :desc => "Add yourself to the organization",
          :default => true
    def create_org
      org = client.organization
      org.name = input[:name]
      org.users = [client.current_user] if input[:add_self]

      with_progress("Creating organization #{c(org.name, :name)}") do
        org.create!
      end

      if input[:target]
        invoke :target, :organization => org
      end
    end

    private

    def ask_name
      ask("Name")
    end
  end
end
