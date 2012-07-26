require "vmc/cli"

module VMC
  class Space < CLI
    def precondition
      super
      fail "This command is v2-only." unless v2?
    end

    def self.by_name(what, obj = what)
      proc { |name, *_|
        client.send(:"#{obj}_by_name", name) ||
          fail("Unknown #{what} '#{name}'")
      }
    end

    def self.space_by_name
      proc { |name, org, *_|
        org.spaces(1, :name => name).first ||
          fail("Unknown space '#{name}'")
      }
    end

    desc "Show space information"
    group :spaces
    input(:organization, :aliases => ["--org", "-o"],
          :from_given => by_name("organization"),
          :desc => "Space's organization") {
      client.current_organization
    }
    input(:space, :argument => :optional, :from_given => space_by_name,
          :desc => "Space to show") {
      client.current_space
    }
    input :full, :type => :boolean,
      :desc => "Show full information for apps, service instances, etc."
    def space(input)
      org = input[:org]
      space = input[:space, org]

      if quiet?
        puts space.name
        return
      end

      line "#{c(space.name, :name)}:"

      indented do
        line "organization: #{c(space.organization.name, :name)}"

        if input[:full]
          line
          line "apps:"

          spaced(space.apps(2)) do |a|
            indented do
              invoke :app, :app => a
            end
          end
        else
          line "apps: #{name_list(space.apps)}"
        end

        if input[:full]
          line
          line "services:"
          spaced(space.service_instances(2)) do |i|
            indented do
              invoke :service, :instance => i
            end
          end
        else
          line "services: #{name_list(space.service_instances)}"
        end
      end
    end


    desc "List spaces in an organization"
    group :spaces
    input(:organization, :aliases => ["--org", "-o"],
          :argument => :optional, :from_given => by_name("organization"),
          :desc => "Organization to list spaces from") {
      client.current_organization
    }
    def spaces(input)
      org = input[:organization]
      spaces =
        with_progress("Getting spaces in #{c(org.name, :name)}") do
          org.spaces
        end

      line unless quiet?

      spaces.each do |s|
        line c(s.name, :name)
      end
    end


    desc "Create a space in an organization"
    group :spaces
    input(:name, :argument => :optional, :desc => "Space name") {
      ask("Name")
    }
    input(:organization, :aliases => ["--org", "-o"],
          :argument => :optional, :from_given => by_name("organization"),
          :desc => "Parent organization") {
      client.current_organization
    }
    input :manager, :type => :boolean, :default => true
    input :developer, :type => :boolean, :default => true
    input :auditor, :type => :boolean, :default => false
    def create_space(input)
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
    end

    private

    def name_list(xs)
      if xs.empty?
        d("none")
      else
        xs.collect { |x| c(x.name, :name) }.join(", ")
      end
    end
  end
end
