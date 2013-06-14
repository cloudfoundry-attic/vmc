require "vmc/cli/start/base"
require "vmc/cli/start/target_interactions"

module VMC::Start
  class Target < Base
    def precondition; end

    desc "Set or display the target cloud, organization, and space"
    group :start
    input :url, :desc => "Target URL to switch to", :argument => :optional
    input :organization, :desc => "Organization" , :aliases => %w{--org -o},
          :from_given => by_name(:organization)
    input :space, :desc => "Space", :alias => "-s",
          :from_given => by_name(:space)
    interactions TargetInteractions
    def target
      unless input.has?(:url) || input.has?(:organization) || \
              input.has?(:space)
        display_target
        display_org_and_space unless quiet?
        return
      end

      if input.has?(:url)
        target = sane_target_url(input[:url])
        with_progress("Setting target to #{c(target, :name)}") do
          begin
            CFoundry::Client.new(target) # check that it's valid before setting
          rescue CFoundry::TargetRefused
            fail "Target refused connection."
          rescue CFoundry::InvalidTarget
            fail "Invalid target URI."
          end

          set_target(target)
        end
      end

      if v2?
        puts "Warning: Targeting a v2 instance. Further commands will fail until a v1 instance is targeted. Please use the 'cf' command to target v2 instances."
      end

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
