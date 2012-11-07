require "vmc/cli"

module VMC
  class Organization < CLI
    def precondition
      check_target
      check_logged_in

      fail "This command is v2-only." unless v2?
    end

    def self.by_name(what, obj = what)
      proc { |name, *_|
        client.send(:"#{obj}_by_name", name) ||
          fail("Unknown #{what} '#{name}'")
      }
    end

    desc "Show organization information"
    group :organizations
    input :organization, :aliases => ["--org", "-o"],
      :argument => :optional,
      :from_given => by_name("organization"),
      :default => proc { client.current_organization },
      :desc => "Organization to show"
    input :full, :type => :boolean,
      :desc => "Show full information for spaces, domains, etc."
    def org
      org = input[:organization]

      unless org
        return if quiet?
        fail "No current organization."
      end

      if quiet?
        puts org.name
        return
      end

      line "#{c(org.name, :name)}:"

      indented do
        line "domains: #{name_list(org.domains)}"

        if input[:full]
          line "spaces:"

          spaced(org.spaces(2)) do |s|
            indented do
              invoke :space, :space => s
            end
          end
        else
          line "spaces: #{name_list(org.spaces)}"
        end
      end
    end


    desc "List available organizations"
    group :organizations
    input :one_line, :alias => "-l", :type => :boolean, :default => false,
      :desc => "Single-line tabular format"
    input :full, :type => :boolean, :default => false,
      :desc => "Show full information for apps, service instances, etc."
    def orgs
      orgs =
        with_progress("Getting organizations") do
          client.organizations(1)
        end

      line unless quiet?

      if input[:one_line]
        table(
          %w{name spaces domains},
          orgs.collect { |o|
            [ c(o.name, :name),
              name_list(o.spaces),
              name_list(o.domains)
            ]
          })
      else
        orgs.each do |o|
          invoke :org, :organization => o, :full => input[:full]
        end
      end
    end


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


    desc "Delete an organization"
    group :organizations
    input(:organization, :aliases => ["--org", "-o"],
          :argument => :optional,
          :from_given => by_name("organization"),
          :desc => "Organization to delete") { |orgs|
      ask "Which organization?", :choices => orgs,
        :display => proc(&:name)
    }
    input(:really, :type => :boolean, :forget => true,
          :default => proc { force? || interact }) { |org|
      ask("Really delete #{c(org.name, :name)}?", :default => false)
    }
    input(:recursive, :alias => "-r", :type => :boolean, :forget => true) {
      ask "Delete #{c("EVERYTHING", :bad)}?", :default => false
    }
    input :warn, :type => :boolean, :default => true,
      :desc => "Show warning if it was the last org"
    def delete_org
      orgs = client.organizations
      fail "No organizations." if orgs.empty?

      org = input[:organization, orgs]
      return unless input[:really, org]

      spaces = org.spaces
      unless spaces.empty?
        unless force?
          line "This organization is not empty!"
          line
          line "spaces: #{name_list(spaces)}"
          line

          return unless input[:recursive]
        end

        spaces.each do |s|
          invoke :delete_space, :space => s, :really => true,
            :recursive => true, :warn => false
        end
      end

      is_current = org == client.current_organization

      with_progress("Deleting organization #{c(org.name, :name)}") do
        org.delete!
      end

      if orgs.size == 1
        return unless input[:warn]

        line
        line c("There are no longer any organizations.", :warning)
        line "You may want to create one with #{c("create-org", :good)}."
      elsif is_current
        invalidate_target
        invoke :target
      end
    end
  end
end
