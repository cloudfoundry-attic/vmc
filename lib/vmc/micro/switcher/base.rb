require 'interact'

module VMC::Micro::Switcher
  class Base
    include Interactive

    def initialize(config)
      @config = config

      @vmrun = VMC::Micro::VMrun.new(config)
      unless @vmrun.running?
        if ask("Micro Cloud Foundry VM is not running. Do you want to start it?", :choices => ['y', 'n']) == 'y'
          display "Starting Micro Cloud Foundry VM: ", false
          @vmrun.start
          say "done".green
        else
          err "Micro Cloud Foundry VM needs to be running."
        end
      end

      err "Micro Cloud Foundry VM initial setup needs to be completed before using 'vmc micro'" unless @vmrun.ready?
    end

    def offline
      unless @vmrun.offline?
        # save online connection type so we can restore it later
        @config['online_connection_type'] = @vmrun.connection_type

        if (@config['online_connection_type'] != 'nat')
          if ask("Reconfigure Micro Cloud Foundry VM network to nat mode and reboot?", :choices => ['y', 'n']) == 'y'
            display "Rebooting Micro Cloud Foundry VM: ", false
            @vmrun.connection_type = 'nat'
            @vmrun.reset
            say "done".green
          else
            err "Aborted"
          end
        end

        display "Setting Micro Cloud Foundry VM to offline mode: ", false
        @vmrun.offline!
        say "done".green
        display "Setting host DNS server: ", false

        @config['domain'] = @vmrun.domain
        @config['ip'] = @vmrun.ip
        set_nameserver(@config['domain'], @config['ip'])
        say "done".green
      else
        say "Micro Cloud Foundry VM already in offline mode".yellow
      end
    end

    def online
      if @vmrun.offline?
        current_connection_type = @vmrun.connection_type
        @config['online_connection_type'] ||= current_connection_type

        if (@config['online_connection_type'] != current_connection_type)
          # TODO handle missing connection type in saved config
          question = "Reconfigure Micro Cloud Foundry VM network to #{@config['online_connection_type']} mode and reboot?"
          if ask(question, :choices => ['y', 'n']) == 'y'
            display "Rebooting Micro Cloud Foundry VM: ", false
            @vmrun.connection_type = @config['online_connection_type']
            @vmrun.reset
            say "done".green
          else
            err "Aborted"
          end
        end

        display "Unsetting host DNS server: ", false
        # TODO handle missing domain and ip in saved config (look at the VM)
        @config['domain'] ||= @vmrun.domain
        @config['ip'] ||= @vmrun.ip
        unset_nameserver(@config['domain'], @config['ip'])
        say "done".green

        display "Setting Micro Cloud Foundry VM to online mode: ", false
        @vmrun.online!
        say "done".green
      else
        say "Micro Cloud Foundry already in online mode".yellow
      end
    end

    def status
      mode = @vmrun.offline? ? 'offline' : 'online'
      say "Micro Cloud Foundry VM currently in #{mode.green} mode"
      # should the VMX path be unescaped?
      say "VMX Path: #{@vmrun.vmx}"
      say "Domain: #{@vmrun.domain.green}"
      say "IP Address: #{@vmrun.ip.green}"
    end
  end

end
