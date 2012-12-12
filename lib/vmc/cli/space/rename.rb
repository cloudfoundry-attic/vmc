require "vmc/cli/space/base"

module VMC::Space
  class Rename < Base
    desc "Rename a space"
    group :spaces, :hidden => true
    input :organization, :desc => "Space's organization",
          :aliases => ["--org", "-o"], :from_given => by_name(:organization),
          :default => proc { client.current_organization }
    input :space, :desc => "Space to rename", :argument => :optional,
          :from_given => by_name(:space)
    input :name, :desc => "New space name", :argument => :optional
    def rename_space
      org = input[:organization]
      space = input[:space, org]
      name = input[:name]

      space.name = name

      with_progress("Renaming to #{c(name, :name)}") do
        space.update!
      end
    end

    private

    def ask_space(org)
      spaces = org.spaces
      fail "No spaces." if spaces.empty?

      ask("Rename which space?", :choices => spaces.sort_by(&:name),
          :display => proc(&:name))
    end

    def ask_name
      ask("New name")
    end
  end
end
