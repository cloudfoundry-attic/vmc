require "vmc/cli/organization/base"

module VMC::Organization
  class Orgs < Base
    desc "List available organizations"
    group :organizations
    input :one_line, :alias => "-l", :type => :boolean, :default => false,
          :desc => "Single-line tabular format"
    input :full, :type => :boolean, :default => false,
          :desc => "Show full information for apps, service instances, etc."
    def orgs
      orgs =
          with_progress("Getting organizations") do
            client.organizations
          end

      line unless quiet?

      if input[:one_line]
        table(
            %w{name spaces domains},
            orgs.collect { |o|
              [ c(o.name, :name),
                name_list(o.spaces),
                name_list(o.domains)
              ]
            })
      else
        orgs.each do |o|
          invoke :org, :organization => o, :full => input[:full]
        end
      end
    end
  end
end