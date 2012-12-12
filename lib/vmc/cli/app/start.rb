require "vmc/cli/app/base"

module VMC::App
  class Start < Base
    APP_CHECK_LIMIT = 60

    desc "Start an application"
    group :apps, :manage
    input :apps, :desc => "Applications to start", :argument => :splat,
          :singular => :app, :from_given => by_name(:app)
    input :debug_mode, :desc => "Debug mode to start in", :aliases => "-d"
    input :all, :desc => "Start all applications", :default => false
    def start
      apps = input[:all] ? client.apps : input[:apps]
      fail "No applications given." if apps.empty?

      spaced(apps) do |app|
        app = filter(:start_app, app)

        switch_mode(app, input[:debug_mode])

        with_progress("Starting #{c(app.name, :name)}") do |s|
          if app.started?
            s.skip do
              err "Already started."
            end
          end

          app.start!
        end

        check_application(app)

        if app.debug_mode && !quiet?
          line
          invoke :instances, :app => app
        end
      end
    end

    # set app debug mode, ensuring it's valid, and shutting it down
    def switch_mode(app, mode)
      mode = nil if mode == "none"
      mode = "run" if mode == "debug_mode" # no value given

      return false if app.debug_mode == mode

      if mode.nil?
        with_progress("Removing debug mode") do
          app.debug_mode = nil
          app.stop! if app.started?
        end

        return true
      end

      with_progress("Switching mode to #{c(mode, :name)}") do |s|
        runtime = client.runtimes.find { |r| r.name == app.runtime.name }
        modes = runtime.debug_modes

        if modes.include?(mode)
          app.debug_mode = mode
          app.stop! if app.started?
        else
          fail "Unknown mode '#{mode}'; available: #{modes.join ", "}"
        end
      end
    end

    def check_application(app)
      with_progress("Checking #{c(app.name, :name)}") do |s|
        if app.debug_mode == "suspend"
          s.skip do
            line "Application is in suspended debugging mode."
            line "It will wait for you to attach to it before starting."
          end
        end

        seconds = 0
        until app.healthy?
          sleep 1
          seconds += 1
          if seconds == APP_CHECK_LIMIT
            s.give_up do
              err "Application failed to start."
              # TODO: print logs
            end
          end
        end
      end
    end
  end
end
