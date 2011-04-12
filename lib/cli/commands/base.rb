
require 'rubygems'
require 'terminal-table/import'
require 'highline/import'

module VMC::Cli

  module Command

    class Base
      attr_reader :no_prompt, :prompt_ok

      def initialize(options={})
        @options = options.dup
        @no_prompt = @options[:noprompts]
        @prompt_ok = !no_prompt

        # Fix for system ruby and Highline (stdin) on MacOSX
        if RUBY_PLATFORM =~ /darwin/ && RUBY_VERSION == '1.8.7' && RUBY_PATCHLEVEL <= 174
          HighLine.track_eof = false
        end

        # Suppress colorize on Windows systems for now.
        if !!RUBY_PLATFORM['mingw'] || !!RUBY_PLATFORM['mswin32'] || !!RUBY_PLATFORM['cygwin']
          VMC::Cli::Config.colorize = false
        end

      end

      def client
        return @client if @client
        @client = VMC::Client.new(target_url, auth_token)
        @client.trace = VMC::Cli::Config.trace if VMC::Cli::Config.trace
        @client.proxy_for @options[:proxy] if @options[:proxy]
        @client
      end

      def client_info
        return @client_info if @client_info
        @client_info = client.info
      end

      def target_url
        return @target_url if @target_url
        @target_url = VMC::Cli::Config.target_url
      end

      def auth_token
        return @auth_token if @auth_token
        @auth_token = VMC::Cli::Config.auth_token
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

