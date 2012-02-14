module VMC::Micro::Switcher

  class Windows < Base
    def version?
      VMC::Micro.run_command("cmd", "/c ver").to_s.scan(/\d+\.\d+/).first.to_f
    end

    def adminrun(command, args=nil)
      if version? > 5.2
        require 'win32ole'
        shell = WIN32OLE.new("Shell.Application")
        shell.ShellExecute(command, args, nil, "runas", 0)
      else
        # on older version this will try to run the command, and if you don't have
        # admin privilges it will tell you so and exit
        VMC::Micro.run_command(command, args)
      end
    end

    # TODO better method to figure out the interface name is to get the NAT ip and find the
    # interface with the correct subnet
    def set_nameserver(domain, ip)
      adminrun("netsh", "interface ip set dns \"VMware Network Adapter VMnet8\" static #{ip}")
    end

    def unset_nameserver(domain, ip)
      adminrun("netsh", "interface ip set dns \"VMware Network Adapter VMnet8\" static none")
    end
  end

end
