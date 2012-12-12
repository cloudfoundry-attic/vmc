require "vmc/cli/app/base"

module VMC::App
  class Crashes < Base
    desc "List an app's crashed instances"
    group :apps, :info, :hidden => true
    input :apps, :desc => "Applications whose crashed instances to list",
          :argument => :splat, :singular => :app, :from_given => by_name(:app)
    def crashes
      apps = input[:apps]
      fail "No applications given." if apps.empty?

      spaced(apps) do |app|
        instances =
          with_progress("Getting crashed instances for #{c(app.name, :name)}") do
            app.crashes
          end

        line unless quiet?

        spaced(instances) do |i|
          if quiet?
            line i.id
          else
            display_crashed_instance(i)
          end
        end
      end
    end

    def display_crashed_instance(i)
      start_line "instance #{c("\##{i.id}", :instance)}: "
      puts "#{b(c("crashed", :error))} "

      indented do
        if s = i.since
          line "since: #{c(s.strftime("%F %r"), :neutral)}"
        end
      end
    end
  end
end
