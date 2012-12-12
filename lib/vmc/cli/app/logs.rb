require "vmc/cli/app/base"

module VMC::App
  class Logs < Base
    desc "Print out an app's logs"
    group :apps, :info, :hidden => true
    input :app, :desc => "Application to get the logs of", :argument => true,
          :from_given => by_name(:app)
    input :instance, :desc => "Instance of application to get the logs of",
          :default => "0"
    input :all, :desc => "Get logs for every instance", :default => false
    def logs
      app = input[:app]

      instances =
        if input[:all] || input[:instance] == "all"
          app.instances
        else
          app.instances.select { |i| i.id == input[:instance] }
        end

      if instances.empty?
        if input[:all]
          fail "No instances found."
        else
          fail "Instance #{app.name} \##{input[:instance]} not found."
        end
      end

      spaced(instances) do |i|
        show_instance_logs(app, i)
      end
    end

    desc "Print out the logs for an app's crashed instances"
    group :apps, :info, :hidden => true
    input :app, :desc => "Application to get the logs of", :argument => true,
          :from_given => by_name(:app)
    def crashlogs
      app = input[:app]

      crashes = app.crashes

      fail "No crashed instances found." if crashes.empty?

      most_recent = crashes.sort_by(&:since).last
      show_instance_logs(app, most_recent)
    end

    def show_instance_logs(app, i)
      return unless i.id

      logs =
        with_progress(
            "Getting logs for #{c(app.name, :name)} " +
              c("\##{i.id}", :instance)) do
          i.files("logs")
        end

      line unless quiet?

      spaced(logs) do |log|
        begin
          body =
            with_progress("Reading " + b(log.join("/"))) do |s|
              i.file(*log)
            end

          lines body
          line unless body.empty?
        rescue CFoundry::NotFound
        end
      end
    end
  end
end
