require "vmc/cli/start/base"
require "vmc/cli/start/target_interactions"

module VMC::Start
  class Target < Base
    desc "Set or display the target cloud, organization, and space"
    group :start
    input :url, :desc => "Target URL to switch to", :argument => :optional
    input :organization, :desc => "Organization" , :aliases => %w{--org -o},
          :from_given => by_name(:organization)
    input :space, :desc => "Space", :alias => "-s",
          :from_given => by_name(:space)
    interactions TargetInteractions
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
