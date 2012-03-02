# only used for testing
module VMC::Micro::Switcher

  class Dummy < Base
    def adminrun(command)
    end

    def set_nameserver(domain, ip)
    end

    def unset_nameserver(domain, ip)
    end
  end

end
