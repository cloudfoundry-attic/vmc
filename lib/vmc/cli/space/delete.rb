require "vmc/cli/space/base"

module VMC::Space
  class Delete < Base
    desc "Delete a space and its contents"
    group :spaces
    input :organization, :desc => "Space's organization",
          :aliases => ["--org", "-o"], :from_given => by_name(:organization),
          :default => proc { client.current_organization }
    input :spaces, :desc => "Spaces to delete", :argument => :splat,
          :singular => :space, :from_given => space_by_name
    input :recursive, :desc => "Delete recursively", :alias => "-r",
          :default => false, :forget => true
    input :warn, :desc => "Show warning if it was the last space",
          :default => true
    input :really, :type => :boolean, :forget => true, :hidden => true,
          :default => proc { force? || interact }
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

    def clear_space(space)
      apps = space.apps
      services = space.service_instances

      return true if apps.empty? && services.empty?

      unless force?
        line "This space is not empty!"
        line
        line "apps: #{name_list(apps)}"
        line "service: #{name_list(services)}"
        line

        return unless input[:recursive]
      end

      apps.each do |a|
        invoke :delete, :app => a, :really => true
      end

      services.each do |i|
        invoke :delete_service, :service => i, :really => true
      end

      true
    end

    private

    def ask_spaces(org)
      spaces = org.spaces
      fail "No spaces." if spaces.empty?

      [ask("Which space in #{c(org.name, :name)}?", :choices => spaces,
           :display => proc(&:name))]
    end

    def ask_really(space)
      ask("Really delete #{c(space.name, :name)}?", :default => false)
    end

    def ask_recursive
      ask "Delete #{c("EVERYTHING", :bad)}?", :default => false
    end
  end
end
