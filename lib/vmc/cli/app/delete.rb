require "set"

require "vmc/cli/app/base"

module VMC::App
  class Delete < Base
    desc "Delete an application"
    group :apps, :manage
    input(:apps, :argument => :splat, :singular => :app,
          :desc => "Applications to delete",
          :from_given => by_name("app")) {
      apps = client.apps
      fail "No applications." if apps.empty?

      [ask("Delete which application?", :choices => apps.sort_by(&:name),
           :display => proc(&:name))]
    }
    input(:really, :type => :boolean, :forget => true,
          :default => proc { force? || interact }) { |name, color|
      ask("Really delete #{c(name, color)}?", :default => false)
    }
    input :routes, :type => :boolean, :default => false,
      :desc => "Delete associated routes"
    input :orphaned, :aliases => "-o", :type => :boolean,
      :desc => "Delete orphaned instances"
    input :all, :type => :boolean, :default => false,
      :desc => "Delete all applications"
    def delete
      apps = client.apps

      if input[:all]
        return unless input[:really, "ALL APPS", :bad]

        to_delete = apps
        others = []
      else
        to_delete = input[:apps]
        others = apps - to_delete
      end

      orphaned = find_orphaned_services(to_delete, others)

      deleted = []
      spaced(to_delete) do |app|
        really = input[:all] || input[:really, app.name, :name]
        next unless really

        deleted << app

        with_progress("Deleting #{c(app.name, :name)}") do
          app.routes.collect(&:delete!) if input[:routes]
          app.delete!
        end
      end

      delete_orphaned_services(orphaned, input[:orphaned])

      to_delete
    end

    def find_orphaned_services(apps, others = [])
      orphaned = Set.new

      apps.each do |a|
        a.services.each do |i|
          if others.none? { |x| x.binds?(i) }
            orphaned << i
          end
        end
      end

      orphaned.each(&:invalidate!)
    end

    def delete_orphaned_services(instances, orphaned)
      return if instances.empty?

      line unless quiet? || force?

      instances.select { |i|
        orphaned ||
          ask("Delete orphaned service instance #{c(i.name, :name)}?",
              :default => false)
      }.each do |instance|
        # TODO: splat
        invoke :delete_service, :instance => instance, :really => true
      end
    end
  end
end
