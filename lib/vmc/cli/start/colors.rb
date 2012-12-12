require "vmc/cli/start/base"

module VMC::Start
  class Colors < Base
    desc "Show color configuration"
    group :start, :hidden => true
    def colors
      user_colors.each do |n, c|
        line "#{n}: #{c(c.to_s, n)}"
      end
    end
  end
end
