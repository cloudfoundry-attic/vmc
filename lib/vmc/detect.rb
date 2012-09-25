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

    # [Framework]
    attr_reader :matches

    # Framework
    attr_reader :default

    def initialize(client, path)
      @client = client
      @path = path
    end

    def framework_info
      @framework_info ||= @client.info[:frameworks]
    end

    def all_runtimes
      @all_runtimes ||= @client.runtimes
    end

    def all_frameworks
      @all_frameworks ||= @client.frameworks
    end

    def matches
      return @matches if @matches

      frameworks = all_frameworks

      @matches = {}

      Clouseau.matches(@path).each do |detected|
        if name = detected.framework_name
          framework = frameworks.find { |f|
            f.name == name.to_s
          }
        end

        if !framework && lang = detected.language_name
          framework = frameworks.find { |f|
            f.name == PSEUDO_FRAMEWORKS[lang]
          }
        end

        next unless framework

        @matches[framework] = detected
      end

      @matches
    end

    def detected_frameworks
      matches.keys
    end

    def detected_runtimes
      langs = Set.new

      Clouseau.matches(@path).each do |detected|
        if lang = detected.language_name
          langs << lang
        end
      end

      runtimes = []

      langs.each do |lang|
        runtimes += runtimes_for(lang)
      end

      runtimes
    end

    def runtimes(framework)
      if matches[framework] && lang = matches[framework].language_name
        runtimes_for(lang)
      end
    end

    def suggested_memory(framework)
      matches[framework] && mem = matches[framework].memory_suggestion
    end

    private

    def runtimes_for(language)
      all_runtimes.select do |r|
        LANGUAGE_RUNTIMES[language] === r.name
      end
    end

    def find_top(entries)
      found = false

      entries.each do |e|
        is_toplevel =
          e.ftype == :directory && e.name.index("/") + 1 == e.name.size

        if is_toplevel && e.name !~ /^(\.|__MACOSX)/
          if found
            return false
          else
            found = e.name
          end
        end
      end

      found
    end
  end
end
