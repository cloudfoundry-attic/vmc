require "vmc/cli/app/base"

module VMC::App
  class Restart < Base
    desc "Stop and start an application"
    group :apps, :manage
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    input :debug_mode, :aliases => "-d",
      :desc => "Debug mode to start in"
    input :all, :type => :boolean, :default => false,
      :desc => "Restart all applications"
    def restart
      invoke :stop, :all => input[:all], :apps => input[:apps]

      line unless quiet?

      invoke :start, :all => input[:all], :apps => input[:apps],
        :debug_mode => input[:debug_mode]
    end
  end
end
