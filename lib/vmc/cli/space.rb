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
      org = input[:organization]
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
    input :target, :alias => "-t", :type => :boolean
    input :manager, :type => :boolean, :default => true,
      :desc => "Add current user as manager"
    input :developer, :type => :boolean, :default => true,
      :desc => "Add current user as developer"
    input :auditor, :type => :boolean, :default => false,
      :desc => "Add current user as auditor"
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

      if input[:target]
        invoke :target, :organization => space.organization,
          :space => space
      end
    end


    desc "Delete a space and its contents"
    group :spaces
    input(:space, :argument => :optional, :from_given => space_by_name,
          :desc => "Space to delete") { |org|
      spaces = org.spaces
      fail "No spaces." if spaces.empty?

      ask "Which space in #{c(org.name, :name)}?", :choices => spaces,
        :display => proc(&:name)
    }
    input(:organization, :aliases => ["--org", "-o"],
          :from_given => by_name("organization"),
          :desc => "Space's organization") {
      client.current_organization
    }
    input(:really, :type => :boolean, :forget => true) { |space|
      force? || ask("Really delete #{c(space.name, :name)}?", :default => false)
    }
    input(:recursive, :alias => "-r", :type => :boolean, :forget => true) {
      ask "Delete #{c("EVERYTHING", :bad)}?", :default => false
    }
    def delete_space(input)
      org = input[:organization]
      space = input[:space, org]
      return unless input[:really, space]

      apps = space.apps
      instances = space.service_instances

      unless apps.empty? && instances.empty?
        unless force?
          line "This space is not empty!"
          line
          line "apps: #{name_list(apps)}"
          line "service instances: #{name_list(instances)}"
          line

          return unless input[:recursive]
        end

        apps.each do |a|
          invoke :delete, :app => a, :really => true
        end

        instances.each do |i|
          invoke :delete_service, :instance => i, :really => true
        end
      end

      is_current = space == client.current_space

      with_progress("Deleting space #{c(space.name, :name)}") do
        space.delete!
      end

      org.invalidate!

      if org.spaces.empty?
        line
        line c("There are no longer any spaces in #{b(org.name)}.", :warning)
        line "You may want to create one with #{c("create-space", :good)}."
      elsif is_current
        invalidate_client
        invoke :target, :organization => client.current_organization
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
