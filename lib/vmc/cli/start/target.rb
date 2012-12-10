require "vmc/detect"
require "vmc/cli/start/base"

module VMC::Start
  class Target < Base
    desc "Set or display the target cloud, organization, and space"
    group :start
    input :url, :argument => :optional, :desc => "Target URL to switch to"
    input(:organization, :aliases => ["--org", "-o"],
          :from_given => by_name("organization"),
          :desc => "Organization") {
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
    }
    input(:space, :alias => "-s",
          :from_given => by_name("space"),
          :desc => "Space") { |org|
      spaces = org.spaces(:depth => 0)

      if spaces.empty?
        unless quiet?
          line
          line c("There are no spaces in #{b(org.name)}.", :warning)
          line "You may want to create one with #{c("create-space", :good)}."
        end
      else
        ask("Space", :choices => spaces, :display => proc(&:name))
      end
    }
    def target
      if !input.given?(:url) && !input.given?(:organization) && !input.given?(:space)
        display_target
        display_org_and_space unless quiet?
        return
      end

      if input.given?(:url)
        target = sane_target_url(input[:url])
        with_progress("Setting target to #{c(target, :name)}") do
          client(target).info # check that it's valid before setting
          set_target(target)
        end
      end

      return unless v2? && client.logged_in?

      if input.given?(:organization) || input.given?(:space)
        info = target_info

        select_org_and_space(input, info)

        save_target_info(info)
      end

      return if quiet?

      invalidate_client

      line
      display_target
      display_org_and_space
    end

    private

    def display_org_and_space
      return unless v2?

      if org = client.current_organization
        line "organization: #{c(org.name, :name)}"
      end

      if space = client.current_space
        line "space: #{c(space.name, :name)}"
      end
    rescue CFoundry::APIError
    end
  end
end
