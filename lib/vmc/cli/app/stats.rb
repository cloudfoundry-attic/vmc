require "vmc/cli/app/base"

module VMC::App
  class Stats < Base
    desc "Display application instance status"
    group :apps, :info, :hidden => true
    input :app, :desc => "Application to get the stats for",
          :argument => true, :from_given => by_name(:app)
    def stats
      app = input[:app]

      stats =
        with_progress("Getting stats for #{c(app.name, :name)}") do |s|
          begin
            app.stats
          rescue CFoundry::StatsError
            s.fail do
              err "Application #{b(app.name)} is not running."
              return
            end
          end
        end

      line unless quiet?

      table(
        %w{instance cpu memory disk},
        stats.sort_by { |idx, _| idx.to_i }.collect { |idx, info|
          idx = c("\##{idx}", :instance)

          if info[:state] == "DOWN"
            [idx, c("down", :bad)]
          else
            stats = info[:stats]
            usage = stats[:usage]

            if usage
              [ idx,
                "#{percentage(usage[:cpu])} of #{b(stats[:cores])} cores",
                "#{usage(usage[:mem], stats[:mem_quota])}",
                "#{usage(usage[:disk], stats[:disk_quota])}"
              ]
            else
              [idx, c("n/a", :neutral)]
            end
          end
        })
    end

    def percentage(num, low = 50, mid = 70)
      color =
        if num <= low
          :good
        elsif num <= mid
          :warning
        else
          :bad
        end

      c(format("%.1f\%", num), color)
    end

    def usage(used, limit)
      "#{b(human_size(used))} of #{b(human_size(limit, 0))}"
    end
  end
end
