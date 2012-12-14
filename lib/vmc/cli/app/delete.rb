require "set"

require "vmc/cli/app/base"

module VMC::App
  class Delete < Base
    desc "Delete an application"
    group :apps, :manage
    input :apps, :desc => "Applications to delete", :argument => :splat,
          :singular => :app, :from_given => by_name(:app)
    input :routes, :desc => "Delete associated routes", :default => false
    input :delete_orphaned, :desc => "Delete orphaned services",
          :aliases => "-o", :default => proc { force? ? false : interact },
          :forget => true
    input :all, :desc => "Delete all applications", :default => false
    input :really, :type => :boolean, :forget => true, :hidden => true,
          :default => proc { force? || interact }
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

      all_services = apps.collect(&:services).flatten
      deleted_app_services = []

      spaced(to_delete) do |app|
        really = input[:all] || input[:really, app.name, :name]
        next unless really

        deleted_app_services += app.services

        with_progress("Deleting #{c(app.name, :name)}") do
          app.routes.collect(&:delete!) if input[:routes]
          app.delete!
        end
      end

      delete_orphaned_services(
        find_orphaned_services(deleted_app_services, all_services))

      to_delete
    end

    def find_orphaned_services(deleted, all)
      orphaned = []

      leftover = all.dup
      deleted.each do |svc|
        leftover.slice!(leftover.index(svc))
        orphaned << svc unless leftover.include?(svc)
      end

      # clear out the relationships as the apps are now deleted
      orphaned.each(&:invalidate!)
    end

    def delete_orphaned_services(orphans)
      return if orphans.empty?

      line unless quiet? || force?

      orphans.select { |o| input[:delete_orphaned, o] }.each do |service|
        # TODO: splat
        invoke :delete_service, :service => service, :really => true
      end
    end

    private

    def ask_apps
      apps = client.apps
      fail "No applications." if apps.empty?

      [ask("Delete which application?", :choices => apps.sort_by(&:name),
           :display => proc(&:name))]
    end

    def ask_really(name, color)
      ask("Really delete #{c(name, color)}?", :default => false)
    end

    def ask_delete_orphaned(service)
      ask("Delete orphaned service #{c(service.name, :name)}?",
          :default => false)
    end
  end
end
