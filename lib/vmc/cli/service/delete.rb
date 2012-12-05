require "vmc/detect"

require "vmc/cli/service/base"

module VMC::Service
  class Delete < Base
    desc "Delete a service"
    group :services, :manage
    input(:instance, :argument => true,
          :from_given => by_name("service instance", :service_instance),
          :desc => "Service to bind") {
      instances = client.service_instances
      fail "No services." if instances.empty?

      ask "Which service instance?", :choices => instances,
        :display => proc(&:name)
    }
    input(:really, :type => :boolean, :forget => true,
          :default => proc { force? || interact }) { |name, color|
      ask("Really delete #{c(name, color)}?", :default => false)
    }
    input(:unbind, :type => :boolean, :forget => true,
          :default => proc { force? || interact }) { |apps|
      names = human_list(apps.collect { |a| c(a.name, :name) })

      ask("Unbind from #{names} before deleting?", :default => true)
    }
    input :all, :type => :boolean, :default => false,
      :desc => "Delete all services"
    def delete_service
      if input[:all]
        return unless input[:really, "ALL SERVICES", :bad]

        client.service_instances.each do |i|
          invoke :delete_service, :instance => i, :really => true
        end

        return
      end

      instance = input[:instance]

      return unless input[:really, instance.name, :name]

      bindings = []

      if v2?
        bindings = instance.service_bindings

        unless bindings.empty? || !input[:unbind, bindings.collect(&:app)]
          bindings.each do |b|
            invoke :unbind_service, :instance => instance, :app => b.app
          end

          bindings = []
        end
      end

      with_progress("Deleting #{c(instance.name, :name)}") do |s|
        if bindings.empty?
          instance.delete!
        else
          s.skip do
            apps = bindings.collect(&:app).collect { |a| b(a.name) }
            err "Service instance is bound to #{human_list(apps)}."
          end
        end
      end
    end

    private

    def human_list(xs)
      if xs.size == 1
        xs.first
      elsif xs.size == 2
        "#{xs.first} and #{xs.last}"
      else
        last = xs.pop
        xs.join(", ") + ", and #{last}"
      end
    end
  end
end
