require 'rubygems'
require 'interact'
require 'terminal-table/import'

module VMC::Cli

  module Command

    class Base
      include Interactive

      attr_reader :no_prompt, :prompt_ok

      MANIFEST = "manifest.yml"

      def initialize(options={})
        @options = options.dup
        @no_prompt = @options[:noprompts]
        @prompt_ok = !no_prompt

        # Suppress colorize on Windows systems for now.
        if WINDOWS
          VMC::Cli::Config.colorize = false
        end

        @path = @options[:path] || '.'

        load_manifest manifest_file if manifest_file
      end

      def manifest_file
        return @options[:manifest] if @options[:manifest]
        return @manifest_file if @manifest_file

        where = File.expand_path(@path)
        while true
          if File.exists?(File.join(where, MANIFEST))
            @manifest_file = File.join(where, MANIFEST)
            break
          elsif File.basename(where) == "/"
            @manifest_file = nil
            break
          else
            where = File.expand_path("../", where)
          end
        end

        @manifest_file
      end

      def load_manifest_structure(file)
        manifest = YAML.load_file file

        Array(manifest["inherit"]).each do |p|
          manifest = merge_parent(manifest, p)
        end

        if apps = manifest["applications"]
          apps.each do |k, v|
            abs = File.expand_path(k, file)
            if Dir.pwd.start_with? abs
              manifest = merge_manifest(manifest, v)
            end
          end
        end

        manifest
      end

      def resolve_manifest(manifest)
        if apps = manifest["applications"]
          apps.each_value do |v|
            resolve_lexically(v, [manifest])
          end
        end

        resolve_lexically(manifest, [manifest])
      end

      def load_manifest(file)
        @manifest = load_manifest_structure(file)
        resolve_manifest(@manifest)
      end

      def merge_parent(child, path)
        file = File.expand_path("../" + path, manifest_file)
        merge_manifest(child, load_manifest_structure(file))
      end

      def merge_manifest(child, parent)
        merge = proc do |_, old, new|
          if new.is_a?(Hash) and old.is_a?(Hash)
            old.merge(new, &merge)
          else
            new
          end
        end

        parent.merge(child, &merge)
      end

      def resolve_lexically(val, ctx = [@manifest])
        case val
        when Hash
          val.each_value do |v|
            resolve_lexically(v, [val] + ctx)
          end
        when Array
          val.each do |v|
            resolve_lexically(v, ctx)
          end
        when String
          val.gsub!(/\$\{([[:alnum:]\-]+)\}/) do
            resolve_symbol($1, ctx)
          end
        end

        nil
      end

      def resolve_symbol(sym, ctx)
        case sym
        when "target-base"
          target_base(ctx)

        when "target-url"
          target_url(ctx)

        when "random-word"
          "%04x" % [rand(0x0100000)]

        else
          found = find_symbol(sym, ctx)

          if found
            resolve_lexically(found, ctx)
            found
          else
            err(sym, "Unknown symbol in manifest: ")
          end
        end
      end

      def find_symbol(sym, ctx)
        ctx.each do |h|
          if val = resolve_in(h, sym)
            return val
          end
        end

        nil
      end

      def resolve_in(hash, *where)
        find_in_hash(hash, ["properties"] + where) ||
          find_in_hash(hash, ["applications", @application] + where) ||
          find_in_hash(hash, where)
      end

      def manifest(*where)
        resolve_in(@manifest, *where)
      end

      def find_in_hash(hash, where)
        what = hash
        where.each do |x|
          return nil unless what.is_a?(Hash)
          what = what[x]
        end

        what
      end

      def target_url(ctx = [])
        find_symbol("target", ctx) ||
          (@client && @client.target) ||
          VMC::Cli::Config.target_url
      end

      def target_base(ctx = [])
        VMC::Cli::Config.base_of(find_symbol("target", ctx) || target_url)
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

      def auth_token
        @auth_token = VMC::Cli::Config.auth_token(@options[:token_file])
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

