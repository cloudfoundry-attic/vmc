require "vmc/cli/space/base"

module VMC::Space
  class Spaces < Base
    desc "List spaces in an organization"
    group :spaces
    input :organization, :desc => "Organization to list spaces from",
          :aliases => %w{--org -o}, :argument => :optional,
          :from_given => by_name(:organization),
          :default => proc { client.current_organization }
    input :name, :desc => "Filter by name"
    input :one_line, :desc => "Single-line tabular format", :alias => "-l",
          :type => :boolean, :default => false
    input :full, :desc => "Show full information for apps, services, etc.",
          :default => false
    def spaces
      org = input[:organization]
      spaces =
        with_progress("Getting spaces in #{c(org.name, :name)}") do
          org.spaces(:depth => quiet? ? 0 : 1)
        end

      line unless quiet?

      spaces.reject! do |s|
        !space_matches?(s, input)
      end

      if input[:one_line]
        table(
          %w{name apps services},
          spaces.collect { |s|
            [ c(s.name, :name),
              name_list(s.apps),
              name_list(s.service_instances)
            ]
          })
      else
        spaced(spaces) do |s|
          invoke :space, :space => s, :full => input[:full]
        end
      end
    end

    private

    def space_matches?(s, options)
      if name = options[:name]
        return false if s.name !~ /#{name}/
      end

      true
    end
  end
end
