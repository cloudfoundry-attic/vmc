# Copyright (c) 2009-2011 VMware, Inc.

require 'addressable/uri'

begin
  require 'caldecott'
rescue LoadError
end

module VMC::Cli
  module TunnelHelper
    PORT_RANGE = 10

    HELPER_APP = File.expand_path("../../../caldecott_helper", __FILE__)

    # bump this AND the version info reported by HELPER_APP/server.rb
    # this is to keep the helper in sync with any updates here
    HELPER_VERSION = '0.0.4'

    def tunnel_uniquename
      random_service_name(tunnel_appname)
    end

    def tunnel_appname
      "caldecott"
    end

    def tunnel_app_info
      return @tun_app_info if @tunnel_app_info
      begin
        @tun_app_info = client.app_info(tunnel_appname)
      rescue => e
        @tun_app_info = nil
      end
    end

    def tunnel_auth
      tunnel_app_info[:env].each do |e|
        name, val = e.split("=", 2)
        return val if name == "CALDECOTT_AUTH"
      end
      nil
    end

    def tunnel_url
      return @tunnel_url if @tunnel_url

      tun_url = tunnel_app_info[:uris][0]

      ["https", "http"].each do |scheme|
        url = "#{scheme}://#{tun_url}"
        begin
          RestClient.get(url)

        # https failed
        rescue Errno::ECONNREFUSED

        # we expect a 404 since this request isn't auth'd
        rescue RestClient::ResourceNotFound
          return @tunnel_url = url
        end
      end

      err "Cannot determine URL for #{tun_url}"
    end

    def invalidate_tunnel_app_info
      @tunnel_url = nil
      @tunnel_app_info = nil
    end

    def tunnel_pushed?
      not tunnel_app_info.nil?
    end

    def tunnel_healthy?(token)
      return false unless tunnel_app_info[:state] == 'STARTED'

      begin
        response = RestClient.get(
          "#{tunnel_url}/info",
          "Auth-Token" => token
        )

        info = JSON.parse(response)
        if info["version"] == HELPER_VERSION
          true
        else
          stop_caldecott
          false
        end
      rescue RestClient::Exception
        stop_caldecott
        false
      end
    end

    def tunnel_bound?(service)
      tunnel_app_info[:services].include?(service)
    end

    def tunnel_connection_info(type, service, token)
      display "Getting tunnel connection info: ", false
      response = nil
      10.times do
        begin
          response = RestClient.get(tunnel_url + "/" + VMC::Client.path("services", service), "Auth-Token" => token)
          break
        rescue RestClient::Exception
          sleep 1
        end

        display ".", false
      end

      unless response
        err "Expected remote tunnel to know about #{service}, but it doesn't"
      end

      display "OK".green

      info = JSON.parse(response)
      case type
      when "rabbitmq"
        uri = Addressable::URI.parse info["url"]
        info["hostname"] = uri.host
        info["port"] = uri.port
        info["vhost"] = uri.path[1..-1]
        info["user"] = uri.user
        info["password"] = uri.password
        info.delete "url"

      # we use "db" as the "name" for mongo
      # existing "name" is junk
      when "mongodb"
        info["name"] = info["db"]
        info.delete "db"

      # our "name" is irrelevant for redis
      when "redis"
        info.delete "name"
      end

      ['hostname', 'port', 'password'].each do |k|
        err "Could not determine #{k} for #{service}" if info[k].nil?
      end

      info
    end

    def display_tunnel_connection_info(info)
      display ''
      display "Service connection info: "

      to_show = [nil, nil, nil] # reserved for user, pass, db name
      info.keys.each do |k|
        case k
        when "host", "hostname", "port", "node_id"
          # skip
        when "user", "username"
          # prefer "username" over "user"
          to_show[0] = k unless to_show[0] == "username"
        when "password"
          to_show[1] = k
        when "name"
          to_show[2] = k
        else
          to_show << k
        end
      end
      to_show.compact!

      align_len = to_show.collect(&:size).max + 1

      to_show.each do |k|
        # TODO: modify the server services rest call to have explicit knowledge
        # about the items to return.  It should return all of them if
        # the service is unknown so that we don't have to do this weird
        # filtering.
        display "  #{k.ljust align_len}: ", false
        display "#{info[k]}".yellow
      end
      display ''
    end

    def start_tunnel(local_port, conn_info, auth)
      @local_tunnel_thread = Thread.new do
        Caldecott::Client.start({
          :local_port => local_port,
          :tun_url => tunnel_url,
          :dst_host => conn_info['hostname'],
          :dst_port => conn_info['port'],
          :log_file => STDOUT,
          :log_level => ENV["VMC_TUNNEL_DEBUG"] || "ERROR",
          :auth_token => auth,
          :quiet => true
        })
      end

      at_exit { @local_tunnel_thread.kill }
    end



    def pick_tunnel_port(port)
      original = port

      PORT_RANGE.times do |n|
        begin
          TCPSocket.open('localhost', port)
          port += 1
        rescue
          return port
        end
      end

      grab_ephemeral_port
    end

    def grab_ephemeral_port
      socket = TCPServer.new('0.0.0.0', 0)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      Socket.do_not_reverse_lookup = true
      port = socket.addr[1]
      socket.close
      return port
    end

    def wait_for_tunnel_start(port)
      10.times do |n|
        begin
          client = TCPSocket.open('localhost', port)
          display '' if n > 0
          client.close
          return true
        rescue => e
          display "Waiting for local tunnel to become available", false if n == 0
          display '.', false
          sleep 1
        end
      end
      err "Could not connect to local tunnel."
    end

    def wait_for_tunnel_end
      display "Open another shell to run command-line clients or"
      display "use a UI tool to connect using the displayed information."
      display "Press Ctrl-C to exit..."
      @local_tunnel_thread.join
    end

    def resolve_symbols(str, info, local_port)
      str.gsub(/\$\{\s*([^\}]+)\s*\}/) do
        case $1
        when "host"
          # TODO: determine proper host
          "localhost"
        when "port"
          local_port
        when "user", "username"
          info["username"]
        else
          info[$1] || ask($1)
        end
      end
    end

    def start_local_prog(clients, command, info, port)
      client = clients[File.basename(command)]

      cmdline = "#{command} "

      case client
      when Hash
        cmdline << resolve_symbols(client["command"], info, port)
        client["environment"].each do |e|
          if e =~ /([^=]+)=(["']?)([^"']*)\2/
            ENV[$1] = resolve_symbols($3, info, port)
          else
            err "Invalid environment variable: #{e}"
          end
        end
      when String
        cmdline << resolve_symbols(client, info, port)
      else
        err "Unknown client info: #{client.inspect}."
      end

      display "Launching '#{cmdline}'"
      display ''

      system(cmdline)
    end

    def push_caldecott(token)
      client.create_app(
        tunnel_appname,
        { :name => tunnel_appname,
          :staging => {:framework => "sinatra"},
          :uris => ["#{tunnel_uniquename}.#{target_base}"],
          :instances => 1,
          :resources => {:memory => 64},
          :env => ["CALDECOTT_AUTH=#{token}"]
        }
      )

      apps_cmd.send(:upload_app_bits, tunnel_appname, HELPER_APP)

      invalidate_tunnel_app_info
    end

    def stop_caldecott
      apps_cmd.stop(tunnel_appname)

      invalidate_tunnel_app_info
    end

    def start_caldecott
      apps_cmd.start(tunnel_appname)

      invalidate_tunnel_app_info
    end

    private

    def apps_cmd
      a = Command::Apps.new(@options)
      a.client client
      a
    end
  end
end
