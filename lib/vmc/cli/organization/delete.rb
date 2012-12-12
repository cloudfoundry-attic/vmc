require "vmc/cli/organization/base"

module VMC::Organization
  class Delete < Base
    desc "Delete an organization"
    group :organizations
    input :organization, :desc => "Organization to delete",
          :aliases => %w{--org -o}, :argument => :optional,
          :from_given => by_name(:organization)
    input :recursive, :desc => "Delete recursively", :alias => "-r",
          :default => false, :forget => true
    input :warn, :desc => "Show warning if it was the last org",
          :default => true
    input :really, :type => :boolean, :forget => true, :hidden => true,
          :default => proc { force? || interact }
    def delete_org
      org = input[:organization]
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

    private

    def ask_organization
      orgs = client.organizations
      fail "No organizations." if orgs.empty?

      ask("Which organization", :choices => orgs.sort_by(&:name),
          :display => proc(&:name))
    end

    def ask_really(org)
      ask("Really delete #{c(org.name, :name)}?", :default => false)
    end

    def ask_recursive
      ask "Delete #{c("EVERYTHING", :bad)}?", :default => false
    end
  end
end
