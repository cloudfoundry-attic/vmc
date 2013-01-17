require "vmc/detect"

module VMC::App
  module Create
    attr_accessor :input
    attr_writer :path

    def get_inputs
      inputs = {}
      inputs[:name] = input[:name]
      inputs[:total_instances] = input[:instances]
      inputs[:space] = client.current_space if client.current_space
      inputs[:production] = !!(input[:plan] =~ /^p/i) if v2?
      inputs[:framework] = framework = determine_framework
      inputs[:command] = input[:command] if can_have_custom_start_command?(framework)
      inputs[:runtime] = determine_runtime(framework)
      inputs[:buildpack] = input[:buildpack] if v2?

      human_mb = human_mb(detector.suggested_memory(framework) || 64)
      inputs[:memory] = megabytes(input[:memory, human_mb])

      inputs
    end

    def determine_framework
      return input[:framework] if input.has?(:framework)

      if (detected_framework = detector.detect_framework)
        input[:framework, [detected_framework], detected_framework, :other]
      else
        input[:framework, detector.all_frameworks, nil, nil]
      end
    end

    def determine_runtime(framework)
      return input[:runtime] if input.has?(:runtime)

      detected_runtimes =
        if framework.name == "standalone"
          detector.detect_runtimes
        else
          detector.runtimes(framework)
        end

      default_runtime = detected_runtimes.size == 1 ? detected_runtimes.first : nil

      if detected_runtimes.empty?
        input[:runtime, detector.all_runtimes, nil, nil]
      else
        input[:runtime, detected_runtimes, default_runtime, :other]
      end
    end

    def create_app(inputs)
      app = client.app

      inputs.each { |key, value| app.send(:"#{key}=", value) }

      app = filter(:create_app, app)

      with_progress("Creating #{c(app.name, :name)}") do
        app.create!
      end

      app
    end

    def map_url(app)
      line unless quiet?

      url = input[:url, app.name]

      mapped_url = false
      until url == "none" || !url || mapped_url
        begin
          invoke :map, :app => app, :url => url
          mapped_url = true
        rescue CFoundry::RouteHostTaken, CFoundry::UriAlreadyTaken => e
          raise if force?

          line c(e.description, :bad)
          line

          input.forget(:url)
          url = input[:url, app.name]

          # version bumps on v1 even though mapping fails
          app.invalidate! unless v2?
        end
      end
    end

    def create_services(app)
      return unless input[:create_services]

      while true
        invoke :create_service, { :app => app }, :plan => :interact
        break unless ask("Create another service?", :default => false)
      end
    end

    def bind_services(app)
      return unless input[:bind_services]

      while true
        invoke :bind_service, :app => app
        break if (all_instances - app.services).empty?
        break unless ask("Bind another service?", :default => false)
      end
    end

    def start_app(app)
      invoke :start, :app => app if input[:start]
    end

    private

    def can_have_custom_start_command?(framework)
      %w(standalone buildpack).include?(framework.name)
    end

    def all_instances
      @all_instances ||= client.service_instances
    end

    def detector
      @detector ||= VMC::Detector.new(client, @path)
    end

    def target_base
      client.target.sub(/^https?:\/\/([^\.]+\.)?(.+)\/?/, '\2')
    end
  end
end
