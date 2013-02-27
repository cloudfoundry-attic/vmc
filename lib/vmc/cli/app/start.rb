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

        if app.started?
          err "Application #{b(app.name)} is already started."
          next
        end

        log = start_app(app)
        stream_start_log(log) if log
        check_application(app)

        if app.debug_mode && !quiet?
          line
          invoke :instances, :app => app
        end
      end
    end

    private

    def start_app(app)
      log = nil
      with_progress("Starting #{c(app.name, :name)}") do
        app.start!(true) do |url|
          log = url
        end
      end
      log
    end

    def stream_start_log(log)
      offset = 0

      while true
        begin
          client.stream_url(log + "&tail&tail_offset=#{offset}") do |out|
            offset += out.size
            print out
          end
        rescue Timeout::Error
        end
      end
    rescue CFoundry::APIError
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
      if app.debug_mode == "suspend"
        line "Application is in suspended debugging mode."
        line "It will wait for you to attach to it before starting."
        return
      end

      line "Checking #{c(app.name, :name)}..."

      seconds = 0
      while instances = app.instances
        indented { print_instances_summary(instances) }

        if all_instances_running?(instances)
          line "#{c("OK", :good)}"
          return
        end

        if any_instance_flapping?(instances) || seconds == APP_CHECK_LIMIT
          err "Application failed to start."
          return
        end

        sleep 1
        seconds += 1
      end
    end

    def all_instances_running?(instances)
      instances.all? { |i| i.state == "RUNNING" }
    end

    def any_instance_flapping?(instances)
      instances.any? { |i| i.state == "FLAPPING" }
    end

    def print_instances_summary(instances)
      counts = Hash.new { 0 }
      instances.each do |i|
        counts[i.state] += 1
      end

      states = []
      %w{RUNNING STARTING DOWN FLAPPING}.each do |state|
        if (num = counts[state]) > 0
          states << "#{b(num)} #{c(state.downcase, state_color(state))}"
        end
      end

      total = instances.count
      running = counts["RUNNING"].to_s.rjust(total.to_s.size)

      ratio = "#{running}#{d("/")}#{total} instances:"
      line "#{ratio} #{states.join(", ")}"
    end
  end
end
