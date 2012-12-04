require "vmc/cli/organization/base"

module VMC::Organization
  class CreateOrg < Base
    desc "Create an organization"
    group :organizations
    input(:name, :argument => :optional, :desc => "Organization name") {
      ask("Name")
    }
    input :target, :alias => "-t", :type => :boolean,
          :desc => "Switch to the organization after creation"
    input :add_self, :type => :boolean, :default => true,
          :desc => "Add yourself to the organization"
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
  end
end