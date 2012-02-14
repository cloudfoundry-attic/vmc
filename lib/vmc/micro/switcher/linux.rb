module VMC::Micro::Switcher

  class Linux < Base
    def set_nameserver(domain, ip)
      puts "Not implemented yet, need to set #{ip} as nameserver in resolv.conf"
      #run_command("sudo", "sed -i'.backup' '1 i nameserver #{ip}' /etc/resolv.conf")
    end

    def unset_nameserver(domain, ip)
      puts "Not implemented yet, need to unset #{ip} in resolv.conf"
      #run_command("sudo", "sed -i'.backup' '/#{ip}/d' /etc/resolv.conf")
    end
  end

end
