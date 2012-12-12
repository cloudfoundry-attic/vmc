require "vmc/cli/space/base"

module VMC::Space
  class Take < Base
    desc "Switch to a space, creating it if it doesn't exist"
    group :spaces, :hidden => true
    input :name, :desc => "Space name", :argument => true
    def take_space
      if space = client.space_by_name(input[:name])
        invoke :target, :space => space
      else
        invoke :create_space, :name => input[:name], :target => true
      end
    end
  end
end
