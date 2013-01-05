module VMC::App
  module PushInteractions
    def ask_name
      ask("Name")
    end

    def ask_url(name)
      choices = url_choices(name)

      options = {
        :choices => choices + ["none"],
        :allow_other => true
      }

      options[:default] = choices.first if choices.size == 1

      ask "URL", options
    end

    def ask_memory(default)
      ask("Memory Limit",
          :choices => memory_choices,
          :allow_other => true,
          :default => default || "64M")
    end

    def ask_instances
      ask("Instances", :default => 1)
    end

    def ask_framework(choices, default, other)
      ask_with_other("Framework", client.frameworks, choices, default, other)
    end

    def ask_runtime(choices, default, other)
      ask_with_other("Runtime", client.runtimes, choices, default, other)
    end

    def ask_command
      if ask("Use custom startup command?", :default => false)
        ask("Startup command")
      end
    end

    def ask_create_services
      line unless quiet?
      ask "Create services for application?", :default => false
    end

    def ask_bind_services
      return if all_instances.empty?

      ask "Bind other services to application?", :default => false
    end

    private

    def ask_with_other(message, all, choices, default, other)
      choices = choices.sort_by(&:name)
      choices << other if other

      opts = {
        :choices => choices,
        :display => proc { |x|
          if other && x == other
            "other"
          else
            x.name
          end
        }
      }

      opts[:default] = default if default

      res = ask(message, opts)

      if other && res == other
        opts[:choices] = all
        res = ask(message, opts)
      end

      res
    end
  end
end
