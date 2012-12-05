require "vmc/detect"

require "vmc/cli/space/base"

module VMC::Space
  class Create < Base
    desc "Create a space in an organization"
    group :spaces
    input(:name, :argument => :optional, :desc => "Space name") {
      ask("Name")
    }
    input :organization, :argument => :optional, :aliases => ["--org", "-o"],
      :from_given => by_name("organization"),
      :default => proc { client.current_organization },
      :desc => "Parent organization"
    input :target, :alias => "-t", :type => :boolean,
      :desc => "Switch to the space after creation"
    input :manager, :type => :boolean, :default => true,
      :desc => "Add current user as manager"
    input :developer, :type => :boolean, :default => true,
      :desc => "Add current user as developer"
    input :auditor, :type => :boolean, :default => false,
      :desc => "Add current user as auditor"
    def create_space
      space = client.space
      space.organization = input[:organization]
      space.name = input[:name]

      with_progress("Creating space #{c(space.name, :name)}") do
        space.create!
      end

      if input[:manager]
        with_progress("Adding you as a manager") do
          space.add_manager client.current_user
        end
      end

      if input[:developer]
        with_progress("Adding you as a developer") do
          space.add_developer client.current_user
        end
      end

      if input[:auditor]
        with_progress("Adding you as an auditor") do
          space.add_auditor client.current_user
        end
      end

      if input[:target]
        invoke :target, :organization => space.organization,
          :space => space
      end
    end
  end
end
