require "vmc/detect"

require "vmc/cli/space/base"

module VMC::Space
  class Rename < Base
    desc "Rename a space"
    group :spaces, :hidden => true
    input :organization, :aliases => ["--org", "-o"],
      :from_given => by_name("organization"),
      :default => proc { client.current_organization },
      :desc => "Space's organization"
    input(:space, :argument => :optional, :from_given => space_by_name,
          :desc => "Space to rename") {
      spaces = client.spaces
      fail "No spaces." if spaces.empty?

      ask("Rename which space?", :choices => spaces.sort_by(&:name),
          :display => proc(&:name))
    }
    input(:name, :argument => :optional, :desc => "New space name") {
      ask("New name")
    }
    def rename_space
      org = input[:organization]
      space = input[:space, org]
      name = input[:name]

      space.name = name

      with_progress("Renaming to #{c(name, :name)}") do
        space.update!
      end
    end
  end
end
