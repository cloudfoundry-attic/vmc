require "vmc/cli/service/base"

module VMC::Service
  class Delete < Base
    desc "Delete a service"
    group :services, :manage
    input :service, :desc => "Service to bind", :argument => :optional,
          :from_given => by_name(:service_instance, :service)
    input :unbind, :desc => "Unbind from applications before deleting?",
          :type => :boolean, :default => proc { force? || interact }
    input :all, :desc => "Delete all services", :default => false
    input :really, :type => :boolean, :forget => true, :hidden => true,
          :default => proc { force? || interact }
    def delete_service
      if input[:all]
        return unless input[:really, "ALL SERVICES", :bad]

        client.service_instances.each do |i|
          invoke :delete_service, :service => i, :really => true
        end

        return
      end

      service = input[:service]

      return unless input[:really, service.name, :name]

      bindings = []

      if v2?
        bindings = service.service_bindings

        unless bindings.empty? || !input[:unbind, bindings.collect(&:app)]
          bindings.each do |b|
            invoke :unbind_service, :service => service, :app => b.app
          end

          bindings = []
        end
      end

      with_progress("Deleting #{c(service.name, :name)}") do |s|
        if bindings.empty?
          service.delete!
        else
          s.skip do
            apps = bindings.collect(&:app).collect { |a| b(a.name) }
            err "Service is bound to #{human_list(apps)}."
          end
        end
      end
    end

    private

    def ask_service
      services = client.service_instances
      fail "No services." if services.empty?

      ask "Which service?", :choices => services,
        :display => proc(&:name)
    end

    def ask_unbind(apps)
      names = human_list(apps.collect { |a| c(a.name, :name) })

      ask("Unbind from #{names} before deleting?", :default => true)
    end

    def ask_really(name, color)
      ask("Really delete #{c(name, color)}?", :default => false)
    end

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
