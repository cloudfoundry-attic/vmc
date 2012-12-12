require "vmc/cli/app/base"

module VMC::App
  class Stop < Base
    desc "Stop an application"
    group :apps, :manage
    input :apps, :desc => "Applications to start", :argument => :splat,
          :singular => :app, :from_given => by_name(:app)
    input :all, :desc => "Stop all applications", :default => false
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
