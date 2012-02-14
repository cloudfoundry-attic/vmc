module VMC::Micro
  class VMrun
    attr_reader :vmx, :vmrun

    def initialize(config)
      @platform = config['platform']
      @user = 'root' # must use root as we muck around with system settings
      @password = config['password']
      @vmrun = config['vmrun']
      @vmx = config['vmx']

      # TODO honor TMPDIR
      if @platform == :windows
        @temp_dir = ENV['temp']
      else
        @temp_dir = '/tmp'
      end
    end

    def connection_type
      read_variable('ethernet0.connectionType')
    end

    def connection_type=(type)
      write_variable("ethernet0.connectionType", type)
    end

    def nat?
      connection_type == "nat"
    end

    def bridged?
      connection_type == "bridged"
    end

    def domain
      # switch to Dir.mktmpdir
      state_config = VMC::Micro.escape_path(File.join(@temp_dir, 'state.yml'))
      run('CopyFileFromGuestToHost', "/var/vcap/bosh/state.yml #{state_config}")
      bosh_config = YAML.load_file(state_config)
      bosh_config['properties']['domain']
    end

    def ip
      # switch to Dir.mktmpdir
      path = VMC::Micro.escape_path(VMC::Micro.config_file('refresh_ip.rb'))
      ip_file = VMC::Micro.escape_path(File.join(@temp_dir, 'ip.txt'))
      run('CopyFileFromHostToGuest', "#{path} /tmp/refresh_ip.rb")
      run('runProgramInGuest', '/tmp/refresh_ip.rb')
      run('CopyFileFromGuestToHost', "/tmp/ip.txt #{ip_file}")
      File.open(ip_file, 'r') { |file| file.read }
    end

    def list
      vms = run("list")
      vms.delete_if { |line| line =~ /^Total/ }
      vms.map { |line| VMC::Micro.escape_path(File.expand_path(line)) }
    end

    def offline?
      command = "-gu #{@user} -gp #{@password} runProgramInGuest"
      args =  '/usr/bin/test -e /var/vcap/micro/offline'
      # why not use run_command?
      result = %x{#{@vmrun} #{command} #{@vmx} #{args}}

      if result.include?('Guest program exited with non-zero exit code: 1')
        return false
      elsif $?.exitstatus == 0
        return true
      else
        raise "failed to execute vmrun:\n#{result}"
      end
    end

    def offline!
      path = VMC::Micro.escape_path(VMC::Micro.config_file('offline.conf'))
      run('CopyFileFromHostToGuest', "#{path} /etc/dnsmasq.d/offline.conf")
      run('runProgramInGuest', '/usr/bin/touch /var/vcap/micro/offline')
      restart_dnsmasq
    end

    def online!
      run('runProgramInGuest', '/bin/rm -f /etc/dnsmasq.d/offline.conf')
      run('runProgramInGuest', '/bin/rm -f /var/vcap/micro/offline')
      restart_dnsmasq
    end

    # check to see if the micro cloud has been configured
    # uses default password to check
    def ready?
      command = "-gu root -gp 'ca$hc0w' runProgramInGuest"
      args =  '/usr/bin/test -e /var/vcap/micro/micro.json'
      result = %x{#{@vmrun} #{command} #{@vmx} #{args}}

      if result.include?('Invalid user name or password for the guest OS') || $?.exitstatus == 0
        return true
      elsif $?.exitstatus == 1
        return false
      else
        raise "failed to execute vmrun:\n#{result}"
      end
    end

    def read_variable(var)
      # TODO deal with non-ok return
      run("readVariable", "runtimeConfig #{var}").first
    end

    def write_variable(var, value)
      run('writeVariable', "runtimeConfig #{var} #{value}")
    end

    def reset
      run('reset', 'soft')
    end

    def restart_dnsmasq
      # restart command doesn't always work, start and stop seems to be more reliable
      run('runProgramInGuest', '/etc/init.d/dnsmasq stop')
      run('runProgramInGuest', '/etc/init.d/dnsmasq start')
    end

    def run(command, args=nil)
      if command.include?('Guest')
        command = "-gu #{@user} -gp #{@password} #{command}"
      end
      VMC::Micro.run_command(@vmrun, "#{command} #{@vmx} #{args}")
    end

    def running?
      vms = list
      if @platform == :windows
        vms.map! { |x| x.downcase }
        vms.include?(@vmx.downcase)
      else
        vms.include?(@vmx)
      end
    end

    def start
      run('start') unless running?
    end

    def stop
      run('stop') if running?
    end

    def self.locate(platform)
      paths = YAML.load_file(VMC::Micro.config_file('paths.yml'))
      vmrun_paths = paths[platform.to_s]['vmrun']
      vmrun_exe = @platform == :windows ? 'vmrun.exe' : 'vmrun'
      vmrun = VMC::Micro.locate_file(vmrun_exe, "VMware", vmrun_paths)
      err "Unable to locate vmrun, please supply --vmrun option" unless vmrun
      vmrun
    end
  end

end
