require "set"
require "yaml"

require "vmc/constants"
require "vmc/cli"

module VMC
  module Plugin
    @@plugins = []

    def self.load_all
      # auto-load gems with 'vmc-plugin' in their name
      enabled =
        Set.new(
          Gem::Specification.find_all { |s|
            s.name =~ /vmc-plugin/
          }.collect(&:name))

      # allow explicit enabling/disabling of gems via config
      plugins = File.expand_path(VMC::PLUGINS_FILE)
      if File.exists?(plugins) && yaml = YAML.load_file(plugins)
        enabled += yaml["enabled"] if yaml["enabled"]
        enabled -= yaml["disabled"] if yaml["disabled"]
      end

      # load up each gem's 'plugin' file
      #
      # we require this file specifically so people can require the gem
      # without it plugging into VMC
      enabled.each do |gemname|
        require "#{gemname}/plugin"
      end
    end
  end

  def self.Plugin(target = CLI, &blk)
    # SUPER FANCY PLUGIN SYSTEM
    target.class_eval &blk
  end
end
