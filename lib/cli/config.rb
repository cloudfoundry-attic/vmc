require "yaml"
require 'fileutils'

require 'rubygems'
require 'json/pure'

module VMC::Cli
  class Config

    DEFAULT_TARGET  = 'api.vcap.me'
    DEFAULT_SUGGEST = 'vcap.me'

    TARGET_FILE    = '~/.vmc_target'
    TOKEN_FILE     = '~/.vmc_token'
    INSTANCES_FILE = '~/.vmc_instances'
    ALIASES_FILE   = '~/.vmc_aliases'

    class << self
      attr_accessor :colorize
      attr_accessor :output
      attr_accessor :trace
      attr_accessor :nozip
      attr_reader   :suggest_url

      def target_url
        return @target_url if @target_url
        target_file = File.expand_path(TARGET_FILE)
        if File.exists? target_file
          @target_url = File.read(target_file).strip!
          ha = @target_url.split('.')
          ha.shift
          @suggest_url = ha.join('.')
          @suggest_url = DEFAULT_SUGGEST if @suggest_url.empty?
        else
          @target_url  = DEFAULT_TARGET
          @suggest_url = DEFAULT_SUGGEST
        end
        @target_url = "http://#{@target_url}" unless /^https?/ =~ @target_url
        @target_url = @target_url.gsub(/\/+$/, '')
        @target_url
      end

      def store_target(target_host)
        target_file = File.expand_path(TARGET_FILE)
        File.open(target_file, 'w+') { |f| f.puts target_host }
        FileUtils.chmod 0600, target_file
      end

      def all_tokens
        token_file = File.expand_path(TOKEN_FILE)
        return nil unless File.exists? token_file
        contents = File.read(token_file).strip
        JSON.parse(contents)
      end

      alias :targets :all_tokens

      def auth_token
        return @token if @token
        tokens = all_tokens
        @token = tokens[target_url] if tokens
      end

      def remove_token_file
        FileUtils.rm_f(File.expand_path(TOKEN_FILE))
      end

      def store_token(token)
        tokens = all_tokens || {}
        tokens[target_url] = token
        token_file = File.expand_path(TOKEN_FILE)
        File.open(token_file, 'w+') { |f| f.write(tokens.to_json) }
        FileUtils.chmod 0600, token_file
      end

      def instances
        instances_file = File.expand_path(INSTANCES_FILE)
        return nil unless File.exists? instances_file
        contents = File.read(instances_file).strip
        JSON.parse(contents)
      end

      def store_instances(instances)
        instances_file = File.expand_path(INSTANCES_FILE)
        File.open(instances_file, 'w') { |f| f.write(instances.to_json) }
      end

      def aliases
        aliases_file = File.expand_path(ALIASES_FILE)
        # bacward compatible
        unless File.exists? aliases_file
          old_aliases_file = File.expand_path('~/.vmc-aliases')
          FileUtils.mv(old_aliases_file, aliases_file) if File.exists? old_aliases_file
        end
        aliases = YAML.load_file(aliases_file) rescue {}
      end

      def store_aliases(aliases)
        aliases_file = File.expand_path(ALIASES_FILE)
        File.open(aliases_file, 'wb') {|f| f.write(aliases.to_yaml)}
      end

    end

    def initialize(work_dir = Dir.pwd)
      @work_dir = work_dir
    end

  end
end
