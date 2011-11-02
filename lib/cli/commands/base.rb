require 'rubygems'
require 'interact'
require 'terminal-table/import'

module VMC::Cli

  module Command

    class Base
      include Interactive
      disable_rewind

      attr_reader :no_prompt, :prompt_ok

      def initialize(options={})
        @options = options.dup
        @no_prompt = @options[:noprompts]
        @prompt_ok = !no_prompt

        # Suppress colorize on Windows systems for now.
        if WINDOWS
          VMC::Cli::Config.colorize = false
        end
      end

      # Inject a client to help in testing.
      def client(cli=nil)
        @client ||= cli
        return @client if @client
        @client = VMC::Client.new(target_url, auth_token)
        @client.trace = VMC::Cli::Config.trace if VMC::Cli::Config.trace
        @client.proxy_for @options[:proxy] if @options[:proxy]
        @client
      end

      def client_info
        @client_info ||= client.info
      end

      def target_url
        @target_url ||= VMC::Cli::Config.target_url
      end

      def target_base
        @target_base ||= VMC::Cli::Config.suggest_url
      end

      def auth_token
        @auth_token ||= VMC::Cli::Config.auth_token
      end

      def runtimes_info
        return @runtimes if @runtimes
        info = client_info
        @runtimes = {}
        if info[:frameworks]
          info[:frameworks].each_value do |f|
            next unless f[:runtimes]
            f[:runtimes].each { |r| @runtimes[r[:name]] = r}
          end
        end
        @runtimes
      end

      def frameworks_info
        return @frameworks if @frameworks
        info = client_info
        @frameworks = []
        if info[:frameworks]
          info[:frameworks].each_value { |f| @frameworks << [f[:name]] }
        end
        @frameworks
      end
    end
  end
end

