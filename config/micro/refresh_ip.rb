#!/var/vcap/bosh/bin/ruby
require 'socket'

A_ROOT_SERVER = '198.41.0.4'

begin
retries ||= 0
route ||= A_ROOT_SERVER
orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
ip_address = UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
rescue Errno::ENETUNREACH
  # happens on boot when dhcp hasn't completed when we get here
   sleep 3
   retries += 1
   retry if retries < 10
ensure
   Socket.do_not_reverse_lookup = orig
end

File.open("/tmp/ip.txt", 'w') { |file| file.write(ip_address) }
