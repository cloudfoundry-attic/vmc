require "vmc/cli/start/base"

module VMC::Start
  class Info < Base
    desc "Display information on the current target, user, etc."
    group :start
    input :runtimes, :desc => "List supported runtimes", :alias => "-r",
          :default => false
    input :frameworks, :desc => "List supported frameworks", :alias => "-f",
          :default => false
    input :services, :desc => "List supported services", :alias => "-s",
          :default => false
    input :all, :desc => "Show all information", :alias => "-a",
          :default => false
    def info
      all = input[:all]

      if all || input[:runtimes]
        runtimes =
            with_progress("Getting runtimes") do
              client.runtimes
            end
      end

      if all || input[:frameworks]
        frameworks =
            with_progress("Getting frameworks") do
              client.frameworks
            end
      end

      if all || input[:services]
        services =
            with_progress("Getting services") do
              client.services
            end
      end

      showing_any = runtimes || services || frameworks

      unless !all && showing_any
        info = client.info

        line if showing_any
        line info[:description]
        line
        line "target: #{b(client.target)}"

        indented do
          line "version: #{info[:version]}"
          line "support: #{info[:support]}"
        end

        if user = client.current_user
          line
          line "user: #{b(user.email || user.guid)}"
        end
      end

      if runtimes
        line unless quiet?

        if runtimes.empty? && !quiet?
          line "#{d("none")}"
        elsif input[:quiet]
          runtimes.each do |r|
            line r.name
          end
        else
          table(
              %w{runtime description},
              runtimes.sort_by(&:name).collect { |r|
                [c(r.name, :name), r.description]
              })
        end
      end

      if frameworks
        line unless quiet?

        if frameworks.empty? && !quiet?
          line "#{d("none")}"
        elsif input[:quiet]
          frameworks.each do |f|
            line f.name
          end
        else
          table(
              %w{framework description},
              frameworks.sort_by(&:name).collect { |f|
                [c(f.name, :name), f.description]
              })
        end
      end

      if services
        line unless quiet?

        if services.empty? && !quiet?
          line "#{d("none")}"
        elsif input[:quiet]
          services.each do |s|
            line s.label
          end
        else
          table(
              ["service", "version", "provider", v2? && "plans", "description"],
              services.sort_by(&:label).collect { |s|
                next if !v2? && s.deprecated?

                [c(s.label, :name),
                 s.version,
                 s.provider,
                 v2? && s.service_plans.collect(&:name).join(", "),
                 s.description
                ]
              })
        end
      end
    end
  end
end
