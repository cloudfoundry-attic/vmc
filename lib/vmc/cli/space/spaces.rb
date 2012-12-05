require "vmc/detect"

require "vmc/cli/space/base"

module VMC::Space
  class Spaces < Base
    desc "List spaces in an organization"
    group :spaces
    input :organization, :argument => :optional, :aliases => ["--org", "-o"],
      :from_given => by_name("organization"),
      :default => proc { client.current_organization },
      :desc => "Organization to list spaces from"
    input :name, :desc => "Filter by name"
    input :one_line, :alias => "-l", :type => :boolean, :default => false,
      :desc => "Single-line tabular format"
    input :full, :type => :boolean, :default => false,
      :desc => "Show full information for apps, service instances, etc."
    def spaces
      org = input[:organization]
      spaces =
        with_progress("Getting spaces in #{c(org.name, :name)}") do
          org.spaces
        end

      line unless quiet?

      spaces.filter! do |s|
        space_matches?(s, input)
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
