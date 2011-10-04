module VMC::Cli::Command
  class Manifest < Base
    include VMC::Cli::ManifestHelper

    def initialize(options)
      super

      # don't resolve any of the manifest template stuff
      if manifest_file
        @manifest = load_manifest_structure manifest_file
      else
        @manifest = {}
      end
    end

    def edit
      build_manifest
      save_manifest
    end

    def extend(which)
      parent = load_manifest_structure which
      @manifest = load_manifest_structure which

      build_manifest

      simplify(@manifest, parent)

      @manifest["inherit"] ||= []
      @manifest["inherit"] << which

      save_manifest(ask("Save where?"))
    end

    private

    def simplify(child, parent)
      return unless child.is_a?(Hash) and parent.is_a?(Hash)

      child.reject! do |k, v|
        if v == parent[k]
          puts "rejecting #{k}"
          true
        else
          simplify(v, parent[k])
          false
        end
      end
    end

    def build_manifest
      @application = ask("Configure for which application?", :default => ".")
      interact true
    end
  end
end
