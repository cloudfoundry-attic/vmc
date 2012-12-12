require "vmc/cli/start/base"

module VMC::Start
  class Targets < Base
    desc "List known targets."
    group :start, :hidden => true
    def targets
      targets_info.each do |target, _|
        line target
        # TODO: print org/space
      end
    end
  end
end


