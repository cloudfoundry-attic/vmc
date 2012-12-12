require "vmc/cli/organization/base"

module VMC::Organization
  class Rename < Base
    desc "Rename an organization"
    group :organizations, :hidden => true
    input :organization, :desc => "Organization to rename",
          :aliases => ["--org", "-o"], :argument => :optional,
          :from_given => by_name(:organization)
    input :name, :desc => "New organization name", :argument => :optional
    def rename_org
      organization = input[:organization]
      name = input[:name]

      organization.name = name

      with_progress("Renaming to #{c(name, :name)}") do
        organization.update!
      end
    end

    private

    def ask_name
      ask("New name")
    end

    def ask_organization
      organizations = client.organizations
      fail "No organizations." if organizations.empty?

      ask("Rename which organization?", :choices => organizations.sort_by(&:name),
          :display => proc(&:name))
    end
  end
end
