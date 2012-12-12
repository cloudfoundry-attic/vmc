module VMC::Start
  module TargetInteractions
    def ask_organization
      orgs = client.organizations(:depth => 0)

      if orgs.empty?
        unless quiet?
          line
          line c("There are no organizations.", :warning)
          line "You may want to create one with #{c("create-org", :good)}."
        end
      elsif orgs.size == 1 && !input.interactive?(:organization)
        orgs.first
      else
        ask("Organization",
            :choices => orgs.sort_by(&:name),
            :display => proc(&:name))
      end
    end

    def ask_space(org)
      spaces = org.spaces(:depth => 0)

      if spaces.empty?
        unless quiet?
          line
          line c("There are no spaces in #{b(org.name)}.", :warning)
          line "You may want to create one with #{c("create-space", :good)}."
        end
      elsif spaces.size == 1 && !input.interactive?(:spaces)
        spaces.first
      else
        ask("Space", :choices => spaces, :display => proc(&:name))
      end
    end
  end
end