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
    input :full, :desc => "Show full information for apps, services, etc.",
          :default => false
    def spaces
      org = input[:organization]
      spaces =
        with_progress("Getting spaces in #{c(org.name, :name)}") do
          org.spaces(:depth => quiet? ? 0 : 1).sort_by(&:name)
        end

      return if spaces.empty?

      line unless quiet?

      spaces.reject! do |s|
        !space_matches?(s, input)
      end

      if input[:full]
        spaced(spaces) do |s|
          invoke :space, :space => s, :full => input[:full]
        end
      else
        table(
          %w{name apps services},
          spaces.collect { |s|
            [ c(s.name, :name),
              name_list(s.apps),
              name_list(s.service_instances)
            ]
          })
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
