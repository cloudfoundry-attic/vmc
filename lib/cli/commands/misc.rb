module VMC::Cli::Command

  class Misc < Base
    def version
      say "vmc #{VMC::Cli::VERSION}"
    end

    def target
      return display JSON.pretty_generate({:target => target_url}) if @options[:json]
      banner "[#{target_url}]"
    end

    def targets
      targets = VMC::Cli::Config.targets
      return display JSON.pretty_generate(targets) if @options[:json]
      return display 'None specified' if targets.empty?
      targets_table = table do |t|
        t.headings = 'Target', 'Authorization'
        targets.each { |target, token| t << [target, token] }
      end
      display "\n"
      display targets_table
    end

    alias :tokens :targets

    def set_target(target_url)
      target_url = "http://#{target_url}" unless /^https?/ =~ target_url
      target_url = target_url.gsub(/\/+$/, '')
      client = VMC::Client.new(target_url)
      unless client.target_valid?
        if prompt_ok
          display "Host is not available or is not valid: '#{target_url}'".red
          show_response = ask "Would you like see the response?",
                              :default => false
          display "\n<<<\n#{client.raw_info}\n>>>\n" if show_response
        end
        exit(false)
      else
        VMC::Cli::Config.store_target(target_url)
        say "Successfully targeted to [#{target_url}]".green
      end
    end

    def info
      info = client_info
      return display JSON.pretty_generate(info) if @options[:json]

      display "\n#{info[:description]}"
      display "For support visit #{info[:support]}"
      display ""
      display "Target:   #{target_url} (v#{info[:version]})"
      display "Client:   v#{VMC::Cli::VERSION}"
      if info[:user]
        display ''
        display "User:     #{info[:user]}"
      end
      if usage = info[:usage] and limits = info[:limits]
        tmem  = pretty_size(limits[:memory]*1024*1024)
        mem   = pretty_size(usage[:memory]*1024*1024)
        tser  = limits[:services]
        ser   = usage[:services]
        tapps = limits[:apps] || 0
        apps  = usage[:apps]  || 0
        display "Usage:    Memory   (#{mem} of #{tmem} total)"
        display "          Services (#{ser} of #{tser} total)"
        display "          Apps     (#{apps} of #{tapps} total)" if limits[:apps]
      end
    end

    def runtimes
      raise VMC::Client::AuthError unless client.logged_in?
      return display JSON.pretty_generate(runtimes_info) if @options[:json]
      return display "No Runtimes" if runtimes_info.empty?
      rtable = table do |t|
        t.headings = 'Name', 'Description', 'Version'
        runtimes_info.each_value { |rt| t << [rt[:name], rt[:description], rt[:version]] }
      end
      display "\n"
      display rtable
    end

    def frameworks
      raise VMC::Client::AuthError unless client.logged_in?
      return display JSON.pretty_generate(frameworks_info) if @options[:json]
      return display "No Frameworks" if frameworks_info.empty?
      rtable = table do |t|
        t.headings = ['Name']
        frameworks_info.each { |f| t << f }
      end
      display "\n"
      display rtable
    end

    def aliases
      aliases = VMC::Cli::Config.aliases
      return display JSON.pretty_generate(aliases) if @options[:json]
      return display "No Aliases" if aliases.empty?
      atable = table do |t|
        t.headings = 'Alias', 'Command'
        aliases.each { |k,v| t << [k, v] }
      end
      display "\n"
      display atable
    end

    def alias(k, v=nil)
      k,v = k.split('=') unless v
      aliases = VMC::Cli::Config.aliases
      aliases[k] = v
      VMC::Cli::Config.store_aliases(aliases)
      display "Successfully aliased '#{k}' to '#{v}'".green
    end

    def unalias(key)
      aliases = VMC::Cli::Config.aliases
      if aliases.has_key?(key)
        aliases.delete(key)
        VMC::Cli::Config.store_aliases(aliases)
        display "Successfully unaliased '#{key}'".green
      else
        display "Unknown alias '#{key}'".red
      end
    end

  end

end

