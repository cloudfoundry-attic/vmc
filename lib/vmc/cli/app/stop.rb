require "vmc/cli/app/base"

module VMC::App
  class Stop < Base
    desc "Stop an application"
    group :apps, :manage
    input :apps, :argument => :splat, :singular => :app,
      :desc => "Applications to start",
      :from_given => by_name("app")
    input :all, :type => :boolean, :default => false,
      :desc => "Stop all applications"
    def stop
      apps = input[:all] ? client.apps : input[:apps]
      fail "No applications given." if apps.empty?

      apps.each do |app|
        with_progress("Stopping #{c(app.name, :name)}") do |s|
          if app.stopped?
            s.skip do
              err "Application is not running."
            end
          end

          app.stop!
        end
      end
    end
  end
end
