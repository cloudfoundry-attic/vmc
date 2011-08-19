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
          @target_url = lock_and_read(target_file).strip!
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
        lock_and_write(target_file, target_host)
      end

      def all_tokens
        token_file = File.expand_path(TOKEN_FILE)
        return nil unless File.exists? token_file
        contents = lock_and_read(token_file).strip
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
        lock_and_write(token_file, tokens.to_json)
      end

      def instances
        instances_file = File.expand_path(INSTANCES_FILE)
        return nil unless File.exists? instances_file
        contents = lock_and_read(instances_file).strip
        JSON.parse(contents)
      end

      def store_instances(instances)
        instances_file = File.expand_path(INSTANCES_FILE)
        lock_and_write(instances_file, instances.to_json)
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

      def lock_and_read(file)
        File.open(file, "r") {|f|
          f.flock(File::LOCK_EX)
          contents = f.read
          f.flock(File::LOCK_UN)
          contents
        }
      end

      def lock_and_write(file, contents)
        File.open(file, File::RDWR | File::CREAT, 0600) {|f|
          f.flock(File::LOCK_EX)
          f.rewind
          f.puts contents
          f.flush
          f.truncate(f.pos)
          f.flock(File::LOCK_UN)
        }
      end
    end

    def initialize(work_dir = Dir.pwd)
      @work_dir = work_dir
    end

  end
end
