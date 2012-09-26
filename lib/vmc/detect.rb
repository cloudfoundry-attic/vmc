require "set"

require "clouseau"

module VMC
  class Detector
    # "Basic" framework names for a detected language
    PSEUDO_FRAMEWORKS = {
      :node => "node",
      :python => "wsgi",
      :java => "java_web",
      :php => "php",
      :erlang => "otp_rebar",
      :dotnet => "dotNet"
    }

    # Clouseau language symbol => matching runtime names
    LANGUAGE_RUNTIMES = {
      :ruby => /^ruby.*/,
      :java => /^java.*/,
      :node => /^node.*/,
      :erlang => /^erlang.*/,
      :dotnet => /^dotNet.*/,
      :python => /^python.*/,
      :php => /^php.*/
    }

    def initialize(client, path)
      @client = client
      @path = path
    end

    # detect the framework
    def detect_framework
      detected && frameworks[detected]
    end

    # detect the language and return the appropriate runtimes
    def detect_runtimes
      if detected && lang = detected.language_name
        runtimes_for(lang)
      end
    end

    # determine runtimes for a given framework based on the language its
    # detector reports itself as
    def runtimes(framework)
      if detector = detectors[framework]
        runtimes_for(detector.language_name)
      end
    end

    # determine suitable memory allocation via the framework's detector
    def suggested_memory(framework)
      if detector = detectors[framework]
        detector.memory_suggestion
      end
    end

    # helper so that this is cached somewhere
    def all_runtimes
      @all_runtimes ||= @client.runtimes
    end

    # helper so that this is cached somewhere
    def all_frameworks
      @all_frameworks ||= @client.frameworks
    end

    private

    def detected
      @detected ||= Clouseau.detect(@path)
    end

    def map_detectors!
      @framework_detectors = {}
      @detector_frameworks = {}

      Clouseau.detectors.each do |d|
        name = d.framework_name.to_s
        lang = d.language_name

        framework = all_frameworks.find { |f|
          f.name == name
        }

        framework ||= all_frameworks.find { |f|
          f.name == PSEUDO_FRAMEWORKS[lang]
        }

        next unless framework

        @framework_detectors[framework] = d
        @detector_frameworks[d] = framework
      end

      nil
    end

    # Framework -> Detector
    def detectors
      map_detectors! unless @framework_detectors
      @framework_detectors
    end

    # Detector -> Framework
    def frameworks
      map_detectors! unless @detector_frameworks
      @detector_frameworks
    end

    def runtimes_for(language)
      all_runtimes.select do |r|
        LANGUAGE_RUNTIMES[language] === r.name
      end
    end
  end
end
