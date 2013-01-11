require "vmc/cli/app/base"

module VMC::App
  class Scale < Base
    desc "Update the instances/memory limit for an application"
    group :apps, :info, :hidden => true
    input :app, :desc => "Application to update", :argument => true,
          :from_given => by_name(:app)
    input :instances, :desc => "Number of instances to run",
          :type => :numeric
    input :memory, :desc => "Memory limit"
    input :plan, :desc => "Application plan", :default => "D100"
    input :restart, :desc => "Restart app after updating?", :default => true
    def scale
      app = input[:app]

      if input.has?(:instances)
        instances = input[:instances, app.total_instances]
      end

      if input.has?(:memory)
        memory = input[:memory, app.memory]
      end

      if input.has?(:plan)
        fail "Plans not supported on target cloud." unless v2?

        plan_name = input[:plan]
        production = !!(plan_name =~ /^p/i)
      end

      unless instances || memory || plan_name
        instances = input[:instances, app.total_instances]
        memory = input[:memory, app.memory]
      end

      memory = megabytes(memory) if memory

      instances_changed = instances && instances != app.total_instances
      memory_changed = memory && memory != app.memory
      plan_changed = plan_name && production != app.production

      unless memory_changed || instances_changed || plan_changed
        fail "No changes!"
      end

      with_progress("Scaling #{c(app.name, :name)}") do
        app.total_instances = instances if instances_changed
        app.memory = memory if memory_changed
        app.production = production if plan_changed
        app.update!
      end

      if memory_changed && app.started? && input[:restart]
        invoke :restart, :app => app
      end
    end

    private

    def ask_instances(default)
      ask("Instances", :default => default)
    end

    def ask_memory(default)
      ask("Memory Limit", :choices => memory_choices(default),
          :default => human_mb(default), :allow_other => true)
    end
  end
end
