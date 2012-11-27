require "vmc/detect"

require "vmc/cli/app/base"

module VMC::App
  class Rename < Base
    desc "Rename an application"
    input(:app, :argument => :optional, :desc => "Application to rename",
          :from_given => by_name("app")) {
      apps = client.apps
      fail "No applications." if apps.empty?

      ask("Rename which application?", :choices => apps.sort_by(&:name),
          :display => proc(&:name))
    }
    input(:name, :argument => :optional, :desc => "New application name") {
      ask("New name")
    }
    def rename
      app = input[:app]
      name = input[:name]

      app.name = name

      with_progress("Renaming to #{c(name, :name)}") do
        app.update!
      end
    end
  end
end
