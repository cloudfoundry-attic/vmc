module VMC::App
  module Sync
    def apply_changes(app)
      app.memory = megabytes(input[:memory]) if input.has?(:memory)
      app.total_instances = input[:instances] if input.has?(:instances)
      app.command = input[:command] if input.has?(:command)
      app.production = input[:plan].upcase.start_with?("P") if input.has?(:plan)
      app.framework = input[:framework] if input.has?(:framework)
      app.runtime = input[:runtime] if input.has?(:runtime)
      app.buildpack = input[:buildpack] if input.has?(:buildpack)
    end

    def display_changes(app)
      return unless app.changed?

      line "Changes:"

      indented do
        app.changes.each do |attr, (old, new)|
          line "#{c(attr, :name)}: #{diff_str(attr, old)} -> #{diff_str(attr, new)}"
        end
      end
    end

    def commit_changes(app)
      if app.changed?
        with_progress("Updating #{c(app.name, :name)}") do
          app.update!
        end
      end

      if input[:restart] && app.started?
        invoke :restart, :app => app
      end
    end

    private

    def diff_str(attr, val)
      case attr
      when :memory
        human_mb(val)
      when :framework, :runtime
        val.name
      when :command
        "'#{val}'"
      when :production
        bool(val)
      else
        val
      end
    end

    def bool(b)
      if b
        c("true", :yes)
      else
        c("false", :no)
      end
    end
  end
end
