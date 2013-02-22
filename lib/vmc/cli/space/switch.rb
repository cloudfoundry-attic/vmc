require "vmc/cli/space/base"

module VMC::Space
  class Switch < Base
    desc "Switch to a space"
    group :spaces, :hidden => true
    input :name, :desc => "Space name", :argument => true
    def switch_space
      if (space = client.space_by_name(input[:name]))
        invoke :target, :space => space
      else
        raise VMC::UserError, "The space #{input[:name]} does not exist, please create the space first."
      end
    end
  end
end
