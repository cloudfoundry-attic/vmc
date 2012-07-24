require "vmc/cli"

module VMC
  class Space < CLI
    def precondition
      super
      fail "This command is v2-only." unless v2?
    end

    def self.by_name(what, obj = what)
      proc { |name, *_|
        client.send(:"#{obj}_by_name", name) ||
          fail("Unknown #{what} '#{name}'")
      }
    end

    desc "Show space information"
    group :spaces
    input(:space, :argument => :optional, :from_given => by_name("space"),
          :desc => "Space to show") {
      client.current_space
    }
    input :full, :type => :boolean,
      :desc => "Show full information for apps, service instances, etc."
    def space(input)
      space = input[:space]

      puts "name: #{c(space.name, :name)}"
      puts "organization: #{c(space.organization.name, :name)}"

      if input[:full]
        line
        line "apps:"

        spaced(space.apps(2)) do |a|
          indented do
            invoke :app, :app => a
          end
        end
      else
        line "apps: #{name_list(space.apps)}"
      end

      if input[:full]
        line
        line "services:"
        spaced(space.service_instances(2)) do |i|
          indented do
            invoke :service, :instance => i
          end
        end
      else
        puts "services: #{name_list(space.service_instances)}"
      end
    end

    private

    def name_list(xs)
      if xs.empty?
        c("none", :dim)
      else
        xs.collect { |x| c(x.name, :name) }.join(", ")
      end
    end
  end
end
