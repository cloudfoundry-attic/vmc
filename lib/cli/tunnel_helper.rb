# Copyright (c) 2009-2011 VMware, Inc.

require 'caldecott'

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
          response = RestClient.get("#{tunnel_url}/services/#{service}", "Auth-Token" => token)
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
      ['hostname', 'port', 'password'].each do |k|
        err "Could not determine #{k} for #{service}" if info[k].nil?
      end

      case type
      # we use "db" as the "name" for mongo
      # existing "name" is junk
      when "mongodb"
        info["name"] = info["db"]
        info.delete "db"

      # our "name" is irrelevant for redis
      when "redis"
        info.delete "name"
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

    def start_tunnel(service, local_port, conn_info, auth)
      display "Starting tunnel to #{service.bold} on port #{local_port.to_s.bold}."

      @local_tunnel_pid = fork do
        Caldecott::Client.start({
          :local_port => local_port,
          :tun_url => tunnel_url,
          :dst_host => conn_info['hostname'],
          :dst_port => conn_info['port'],
          :log_file => STDOUT,
          :log_level => "ERROR",
          :auth_token => auth,
          :quiet => true
        })
      end

      at_exit { Process.kill("KILL", @local_tunnel_pid) }
    end

    def pick_tunnel_port(port)
      original = port

      PORT_RANGE.times do |n|
        begin
          TCPSocket.open('localhost', port)
          port += 1
        rescue => e
          return port
        end
      end

      err "Could not pick a port between #{original} and #{original + PORT_RANGE - 1}"
    end

    def wait_for_tunnel_start(port)
      10.times do |n|
        begin
          TCPSocket.open('localhost', port)
          display '' if n > 0
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
      display "Press Ctrl-C to exit..."
      Process.wait(@local_tunnel_pid)
    end

    def local_prog_cmdline(command, local_port, tunnel_info)
      cmd = command.dup
      cmd.gsub!(/\$\{\s*([^\}]+)\s*\}/) do
        case $1
        when "host"
          # TODO: determine proper host
          "localhost"
        when "port"
          local_port
        when "user", "username"
          tunnel_info["username"]
        else
          tunnel_info[$1] || err("Unknown symbol '#{$1}'")
        end
      end
      cmd
    end

    def start_local_prog(which, cmdline)
      display "Launching '#{cmdline}'"
      display ''
      unless system(cmdline)
        err "Failed to start '#{which}' client; is it in your $PATH?"
      end
    end

    def push_caldecott(token)
      client.create_app(
        tunnel_appname,
        { :name => tunnel_appname,
          :staging => {:framework => "sinatra"},
          :uris => ["#{tunnel_uniquename}.#{VMC::Cli::Config.suggest_url}"],
          :instances => 1,
          :resources => {:memory => 64},
          :env => ["CALDECOTT_AUTH=#{token}"]
        }
      )

      Command::Apps.new({}).send(:upload_app_bits, tunnel_appname, HELPER_APP)

      invalidate_tunnel_app_info
    end

    def stop_caldecott
      Command::Apps.new({}).stop(tunnel_appname)

      invalidate_tunnel_app_info
    end

    def start_caldecott
      Command::Apps.new({}).start(tunnel_appname)

      invalidate_tunnel_app_info
    end
  end
end
