require "vmc/cli/app/base"

module VMC::App
  class Health < Base
    desc "Get application health"
    group :apps, :info, :hidden => true
    input :apps, :desc => "Applications to start", :argument => :splat,
          :singular => :app, :from_given => by_name(:app)
    def health
      apps = input[:apps]
      fail "No applications given." if apps.empty?

      health =
        with_progress("Getting health status") do
          apps.collect { |a| [a, app_status(a)] }
        end

      line unless quiet?

      spaced(health) do |app, status|
        start_line "#{c(app.name, :name)}: " unless quiet?
        puts status
      end
    end
  end
end
