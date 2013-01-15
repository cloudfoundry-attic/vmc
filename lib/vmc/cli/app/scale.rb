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
    input :disk, :desc => "Disk quota"
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

      if input.has?(:disk)
        disk = input[:disk, human_mb(app.disk_quota)]
      end

      if input.has?(:plan)
        fail "Plans not supported on target cloud." unless v2?

        plan_name = input[:plan]
        production = !!(plan_name =~ /^p/i)
      end

      unless instances || memory || disk || plan_name
        instances = input[:instances, app.total_instances]
        memory = input[:memory, app.memory]
      end

      app.total_instances = instances if input.has?(:instances)
      app.memory = megabytes(memory) if input.has?(:memory)
      app.disk_quota = megabytes(disk) if input.has?(:disk)
      app.production = production if input.has?(:plan)

      fail "No changes!" unless app.changed?

      with_progress("Scaling #{c(app.name, :name)}") do
        app.update!
      end

      needs_restart = app.changes.key?(:memory) || app.changes.key?(:disk_quota)

      if needs_restart && app.started? && input[:restart]
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
