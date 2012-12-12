require "vmc/cli/space/base"

module VMC::Space
  class Create < Base
    desc "Create a space in an organization"
    group :spaces
    input :name, :desc => "Space name", :argument => :optional
    input :organization, :desc => "Parent organization",
          :argument => :optional, :aliases => ["--org", "-o"],
          :from_given => by_name(:organization),
          :default => proc { client.current_organization }
    input :target, :desc => "Switch to the space after creation",
          :alias => "-t", :default => false
    input :manager, :desc => "Add yourself as manager", :default => true
    input :developer, :desc => "Add yourself as developer", :default => true
    input :auditor, :desc => "Add yourself as auditor", :default => false
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

    private

    def ask_name
      ask("Name")
    end
  end
end
