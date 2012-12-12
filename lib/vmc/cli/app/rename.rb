require "vmc/cli/app/base"

module VMC::App
  class Rename < Base
    desc "Rename an application"
    group :apps, :manage, :hidden => true
    input :app, :desc => "Application to rename", :argument => :optional,
          :from_given => by_name(:app)
    input :name, :desc => "New application name", :argument => :optional
    def rename
      app = input[:app]
      name = input[:name]

      app.name = name

      with_progress("Renaming to #{c(name, :name)}") do
        app.update!
      end
    end

    private

    def ask_app
      apps = client.apps
      fail "No applications." if apps.empty?

      ask("Rename which application?", :choices => apps.sort_by(&:name),
          :display => proc(&:name))
    end

    def ask_name
      ask("New name")
    end
  end
end
