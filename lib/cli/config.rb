require "yaml"
require 'fileutils'

require 'rubygems'
require 'json/pure'

module VMC::Cli
  class Config

    DEFAULT_TARGET  = 'api.vcap.me'

    TARGET_FILE    = '~/.vmc_target'
    TOKEN_FILE     = '~/.vmc_token'
    INSTANCES_FILE = '~/.vmc_instances'
    ALIASES_FILE   = '~/.vmc_aliases'
    CLIENTS_FILE   = '~/.vmc_clients'
    MICRO_FILE     = '~/.vmc_micro'

    STOCK_CLIENTS = File.expand_path("../../../config/clients.yml", __FILE__)

    class << self
      attr_accessor :colorize
      attr_accessor :output
      attr_accessor :trace
      attr_accessor :nozip

      def target_url
        return @target_url if @target_url
        target_file = File.expand_path(TARGET_FILE)
        if File.exists? target_file
          @target_url = lock_and_read(target_file).strip
        else
          @target_url  = DEFAULT_TARGET
        end
        @target_url = "http://#{@target_url}" unless /^https?/ =~ @target_url
        @target_url = @target_url.gsub(/\/+$/, '')
        @target_url
      end

      def base_of(url)
        url.sub(/^[^\.]+\./, "")
      end

      def suggest_url
        @suggest_url ||= base_of(target_url)
      end

      def store_target(target_host)
        target_file = File.expand_path(TARGET_FILE)
        lock_and_write(target_file, target_host)
      end

      def all_tokens(token_file_path=nil)
        token_file = File.expand_path(token_file_path || TOKEN_FILE)
        return nil unless File.exists? token_file
        contents = lock_and_read(token_file).strip
        JSON.parse(contents)
      end

      alias :targets :all_tokens

      def auth_token(token_file_path=nil)
        return @token if @token
        tokens = all_tokens(token_file_path)
        @token = tokens[target_url] if tokens
      end

      def remove_token_file
        FileUtils.rm_f(File.expand_path(TOKEN_FILE))
      end

      def store_token(token, token_file_path=nil)
        tokens = all_tokens(token_file_path) || {}
        tokens[target_url] = token
        token_file = File.expand_path(token_file_path || TOKEN_FILE)
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

      def micro
        micro_file = File.expand_path(MICRO_FILE)
        return {} unless File.exists? micro_file
        contents = lock_and_read(micro_file).strip
        JSON.parse(contents)
      end

      def store_micro(micro)
        micro_file = File.expand_path(MICRO_FILE)
        lock_and_write(micro_file, micro.to_json)
      end

      def deep_merge(a, b)
        merge = proc do |_, old, new|
          if new.is_a?(Hash) and old.is_a?(Hash)
            old.merge(new, &merge)
          else
            new
          end
        end

        a.merge(b, &merge)
      end

      def clients
        return @clients if @clients

        stock = YAML.load_file(STOCK_CLIENTS)
        clients = File.expand_path CLIENTS_FILE
        if File.exists? clients
          user = YAML.load_file(clients)
          @clients = deep_merge(stock, user)
        else
          @clients = stock
        end
      end

      def lock_and_read(file)
        File.open(file, File::RDONLY) {|f|
          if defined? JRUBY_VERSION
            f.flock(File::LOCK_SH)
          else
            f.flock(File::LOCK_EX)
          end
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
