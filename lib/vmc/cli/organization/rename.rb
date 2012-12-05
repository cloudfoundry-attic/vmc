require "vmc/detect"

require "vmc/cli/organization/base"

module VMC::Organization
  class Rename < Base
    desc "Rename an organization"
    group :organizations, :hidden => true
    input(:organization, :aliases => ["--org", "-o"],
          :argument => :optional, :desc => "Organization to rename",
          :from_given => by_name("organization")) {
      organizations = client.organizations
      fail "No organizations." if organizations.empty?

      ask("Rename which organization?", :choices => organizations.sort_by(&:name),
          :display => proc(&:name))
    }
    input(:name, :argument => :optional, :desc => "New organization name") {
      ask("New name")
    }
    def rename_org
      organization = input[:organization]
      name = input[:name]

      organization.name = name

      with_progress("Renaming to #{c(name, :name)}") do
        organization.update!
      end
    end
  end
end
