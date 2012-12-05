require "vmc/detect"

require "vmc/cli/space/base"

module VMC::Space
  class Delete < Base
    desc "Delete a space and its contents"
    group :spaces
    input(:spaces, :argument => :splat,
          :from_given => space_by_name,
          :desc => "Space to delete") { |org|
      spaces = org.spaces
      fail "No spaces." if spaces.empty?

      [ask("Which space in #{c(org.name, :name)}?", :choices => spaces,
           :display => proc(&:name))]
    }
    input :organization, :aliases => ["--org", "-o"],
      :from_given => by_name("organization"),
      :default => proc { client.current_organization },
      :desc => "Space's organization"
    input(:really, :type => :boolean, :forget => true,
          :default => proc { force? || interact }) { |space|
      ask("Really delete #{c(space.name, :name)}?", :default => false)
    }
    input(:recursive, :alias => "-r", :type => :boolean, :forget => true) {
      ask "Delete #{c("EVERYTHING", :bad)}?", :default => false
    }
    input :warn, :type => :boolean, :default => true,
      :desc => "Show warning if it was the last space"
    def delete_space
      org = input[:organization]
      spaces = input[:spaces, org]

      deleted_current = false

      spaces.each do |space|
        next unless input[:really, space]

        next unless clear_space(space)

        deleted_current ||= space == client.current_space

        with_progress("Deleting space #{c(space.name, :name)}") do
          space.delete!
        end
      end

      org.invalidate!

      if org.spaces.empty?
        return unless input[:warn]

        line
        line c("There are no longer any spaces in #{b(org.name)}.", :warning)
        line "You may want to create one with #{c("create-space", :good)}."
      elsif deleted_current
        invalidate_client
        invoke :target, :organization => client.current_organization
      end
    end

    private

    def clear_space(space)
      apps = space.apps
      instances = space.service_instances

      return true if apps.empty? && instances.empty?

      unless force?
        line "This space is not empty!"
        line
        line "apps: #{name_list(apps)}"
        line "service instances: #{name_list(instances)}"
        line

        return unless input[:recursive]
      end

      apps.each do |a|
        invoke :delete, :app => a, :really => true
      end

      instances.each do |i|
        invoke :delete_service, :instance => i, :really => true
      end

      true
    end
  end
end
