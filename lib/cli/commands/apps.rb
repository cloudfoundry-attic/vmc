require 'digest/sha1'
require 'fileutils'
require 'pathname'
require 'tempfile'
require 'tmpdir'
require 'set'
require "uuidtools"
require 'socket'

module VMC::Cli::Command

  class Apps < Base
    include VMC::Cli::ServicesHelper
    include VMC::Cli::ManifestHelper
    include VMC::Cli::TunnelHelper
    include VMC::Cli::ConsoleHelper

    def list
      apps = client.apps
      apps.sort! {|a, b| a[:name] <=> b[:name] }
      return display JSON.pretty_generate(apps || []) if @options[:json]

      display "\n"
      return display "No Applications" if apps.nil? || apps.empty?

      apps_table = table do |t|
        t.headings = 'Application', '# ', 'Health', 'URLS', 'Services'
        apps.each do |app|
          t << [app[:name], app[:instances], health(app), app[:uris].join(', '), app[:services].join(', ')]
        end
      end
      display apps_table
    end

    alias :apps :list

    SLEEP_TIME  = 1
    LINE_LENGTH = 80

    # Numerators are in secs
    TICKER_TICKS  = 25/SLEEP_TIME
    HEALTH_TICKS  = 5/SLEEP_TIME
    TAIL_TICKS    = 45/SLEEP_TIME
    GIVEUP_TICKS  = 120/SLEEP_TIME

    def info(what, default=nil)
      @options[what] || (@app_info && @app_info[what.to_s]) || default
    end

    def console(appname, interactive=true)
      unless defined? Caldecott
        display "To use `vmc rails-console', you must first install Caldecott:"
        display ""
        display "\tgem install caldecott"
        display ""
        display "Note that you'll need a C compiler. If you're on OS X, Xcode"
        display "will provide one. If you're on Windows, try DevKit."
        display ""
        display "This manual step will be removed in the future."
        display ""
        err "Caldecott is not installed."
      end

      #Make sure there is a console we can connect to first
      conn_info = console_connection_info appname

      port = pick_tunnel_port(@options[:port] || 20000)

      raise VMC::Client::AuthError unless client.logged_in?

      if not tunnel_pushed?
        display "Deploying tunnel application '#{tunnel_appname}'."
        auth = UUIDTools::UUID.random_create.to_s
        push_caldecott(auth)
        start_caldecott
      else
        auth = tunnel_auth
      end

      if not tunnel_healthy?(auth)
        display "Redeploying tunnel application '#{tunnel_appname}'."
        # We don't expect caldecott not to be running, so take the
        # most aggressive restart method.. delete/re-push
        client.delete_app(tunnel_appname)
        invalidate_tunnel_app_info
        push_caldecott(auth)
        start_caldecott
      end

      start_tunnel(port, conn_info, auth)
      wait_for_tunnel_start(port)
      start_local_console(port, appname) if interactive
      port
    end

    def start(appname=nil, push=false)
      if appname
        do_start(appname, push)
      else
        each_app do |name|
          do_start(name, push)
        end
      end
    end

    def stop(appname=nil)
      if appname
        do_stop(appname)
      else
        reversed = []
        each_app do |name|
          reversed.unshift name
        end

        reversed.each do |name|
          do_stop(name)
        end
      end
    end

    def restart(appname=nil)
      stop(appname)
      start(appname)
    end

    def mem(appname, memsize=nil)
      app = client.app_info(appname)
      mem = current_mem = mem_quota_to_choice(app[:resources][:memory])
      memsize = normalize_mem(memsize) if memsize

      memsize ||= ask(
        "Update Memory Reservation?",
        :default => current_mem,
        :choices => mem_choices
      )

      mem         = mem_choice_to_quota(mem)
      memsize     = mem_choice_to_quota(memsize)
      current_mem = mem_choice_to_quota(current_mem)

      display "Updating Memory Reservation to #{mem_quota_to_choice(memsize)}: ", false

      # check memsize here for capacity
      check_has_capacity_for((memsize - mem) * app[:instances])

      mem = memsize

      if (mem != current_mem)
        app[:resources][:memory] = mem
        client.update_app(appname, app)
        display 'OK'.green
        restart appname if app[:state] == 'STARTED'
      else
        display 'OK'.green
      end
    end

    def map(appname, url)
      app = client.app_info(appname)
      uris = app[:uris] || []
      uris << url
      app[:uris] = uris
      client.update_app(appname, app)
      display "Successfully mapped url".green
    end

    def unmap(appname, url)
      app = client.app_info(appname)
      uris = app[:uris] || []
      url = url.gsub(/^http(s*):\/\//i, '')
      deleted = uris.delete(url)
      err "Invalid url" unless deleted
      app[:uris] = uris
      client.update_app(appname, app)
      display "Successfully unmapped url".green
    end

    def delete(appname=nil)
      force = @options[:force]
      if @options[:all]
        if no_prompt || force || ask("Delete ALL applications?", :default => false)
          apps = client.apps
          apps.each { |app| delete_app(app[:name], force) }
        end
      else
        err 'No valid appname given' unless appname
        delete_app(appname, force)
      end
    end

    def files(appname, path='/')
      return all_files(appname, path) if @options[:all] && !@options[:instance]
      instance = @options[:instance] || '0'
      content = client.app_files(appname, path, instance)
      display content
    rescue VMC::Client::NotFound, VMC::Client::TargetError
      err 'No such file or directory'
    end

    def logs(appname)
      # Check if we have an app before progressing further
      client.app_info(appname)
      return grab_all_logs(appname) if @options[:all] && !@options[:instance]
      instance = @options[:instance] || '0'
      grab_logs(appname, instance)
    end

    def crashes(appname, print_results=true, since=0)
      crashed = client.app_crashes(appname)[:crashes]
      crashed.delete_if { |c| c[:since] < since }
      instance_map = {}

#      return display JSON.pretty_generate(apps) if @options[:json]


      counter = 0
      crashed = crashed.to_a.sort { |a,b| a[:since] - b[:since] }
      crashed_table = table do |t|
        t.headings = 'Name', 'Instance ID', 'Crashed Time'
        crashed.each do |crash|
          name = "#{appname}-#{counter += 1}"
          instance_map[name] = crash[:instance]
          t << [name, crash[:instance], Time.at(crash[:since]).strftime("%m/%d/%Y %I:%M%p")]
        end
      end

      VMC::Cli::Config.store_instances(instance_map)

      if @options[:json]
        return display JSON.pretty_generate(crashed)
      elsif print_results
        display "\n"
        if crashed.empty?
          display "No crashed instances for [#{appname}]" if print_results
        else
          display crashed_table if print_results
        end
      end

      crashed
    end

    def crashlogs(appname)
      instance = @options[:instance] || '0'
      grab_crash_logs(appname, instance)
    end

    def instances(appname, num=nil)
      if num
        change_instances(appname, num)
      else
        get_instances(appname)
      end
    end

    def stats(appname=nil)
      if appname
        display "\n", false
        do_stats(appname)
      else
        each_app do |n|
          display "\n#{n}:"
          do_stats(n)
        end
      end
    end

    def update(appname=nil)
      if appname
        app = client.app_info(appname)
        if @options[:canary]
          display "[--canary] is deprecated and will be removed in a future version".yellow
        end
        upload_app_bits(appname, @path)
        restart appname if app[:state] == 'STARTED'
      else
        each_app do |name|
          display "Updating application '#{name}'..."

          app = client.app_info(name)
          upload_app_bits(name, @application)
          restart name if app[:state] == 'STARTED'
        end
      end
    end

    def push(appname=nil)
      unless no_prompt || @options[:path]
        proceed = ask(
          'Would you like to deploy from the current directory?',
          :default => true
        )

        unless proceed
          @path = ask('Deployment path')
        end
      end

      pushed = false
      each_app(false) do |name|
        display "Pushing application '#{name}'..." if name
        do_push(name)
        pushed = true
      end

      unless pushed
        @application = @path
        do_push(appname)
      end
    end

    def environment(appname)
      app = client.app_info(appname)
      env = app[:env] || []
      return display JSON.pretty_generate(env) if @options[:json]
      return display "No Environment Variables" if env.empty?
      etable = table do |t|
        t.headings = 'Variable', 'Value'
        env.each do |e|
          k,v = e.split('=', 2)
          t << [k, v]
        end
      end
      display "\n"
      display etable
    end

    def environment_add(appname, k, v=nil)
      app = client.app_info(appname)
      env = app[:env] || []
      k,v = k.split('=', 2) unless v
      env << "#{k}=#{v}"
      display "Adding Environment Variable [#{k}=#{v}]: ", false
      app[:env] = env
      client.update_app(appname, app)
      display 'OK'.green
      restart appname if app[:state] == 'STARTED'
    end

    def environment_del(appname, variable)
      app = client.app_info(appname)
      env = app[:env] || []
      deleted_env = nil
      env.each do |e|
        k,v = e.split('=')
        if (k == variable)
          deleted_env = e
          break;
        end
      end
      display "Deleting Environment Variable [#{variable}]: ", false
      if deleted_env
        env.delete(deleted_env)
        app[:env] = env
        client.update_app(appname, app)
        display 'OK'.green
        restart appname if app[:state] == 'STARTED'
      else
        display 'OK'.green
      end
    end

    private

    def app_exists?(appname)
      app_info = client.app_info(appname)
      app_info != nil
    rescue VMC::Client::NotFound
      false
    end

    def check_deploy_directory(path)
      err 'Deployment path does not exist' unless File.exists? path
      return if File.expand_path(Dir.tmpdir) != File.expand_path(path)
      err "Can't deploy applications from staging directory: [#{Dir.tmpdir}]"
    end

    def check_unreachable_links(path)
      files = Dir.glob("#{path}/**/*", File::FNM_DOTMATCH)

      pwd = Pathname.pwd

      abspath = File.expand_path(path)
      unreachable = []
      files.each do |f|
        file = Pathname.new(f)
        if file.symlink? && !file.realpath.to_s.start_with?(abspath)
          unreachable << file.relative_path_from(pwd)
        end
      end

      unless unreachable.empty?
        root = Pathname.new(path).relative_path_from(pwd)
        err "Can't deploy application containing links '#{unreachable}' that reach outside its root '#{root}'"
      end
    end

    def find_sockets(path)
      files = Dir.glob("#{path}/**/*", File::FNM_DOTMATCH)
      files && files.select { |f| File.socket? f }
    end

    def upload_app_bits(appname, path)
      display 'Uploading Application:'

      upload_file, file = "#{Dir.tmpdir}/#{appname}.zip", nil
      FileUtils.rm_f(upload_file)

      explode_dir = "#{Dir.tmpdir}/.vmc_#{appname}_files"
      FileUtils.rm_rf(explode_dir) # Make sure we didn't have anything left over..

      if path =~ /\.(war|zip)$/
        #single file that needs unpacking
        VMC::Cli::ZipUtil.unpack(path, explode_dir)
      elsif !File.directory? path
        #single file that doesn't need unpacking
        FileUtils.mkdir(explode_dir)
        FileUtils.cp(path,explode_dir)
      else
        Dir.chdir(path) do
          # Stage the app appropriately and do the appropriate fingerprinting, etc.
          if war_file = Dir.glob('*.war').first
            VMC::Cli::ZipUtil.unpack(war_file, explode_dir)
          elsif zip_file = Dir.glob('*.zip').first
            VMC::Cli::ZipUtil.unpack(zip_file, explode_dir)
          else
            check_unreachable_links(path)
            FileUtils.mkdir(explode_dir)

            files = Dir.glob('{*,.[^\.]*}')

            # Do not process .git files
            files.delete('.git') if files

            FileUtils.cp_r(files, explode_dir)

            find_sockets(explode_dir).each do |s|
              File.delete s
            end
          end
        end
      end

      # Send the resource list to the cloudcontroller, the response will tell us what it already has..
      unless @options[:noresources]
        display '  Checking for available resources: ', false
        fingerprints = []
        total_size = 0
        resource_files = Dir.glob("#{explode_dir}/**/*", File::FNM_DOTMATCH)
        resource_files.each do |filename|
          next if (File.directory?(filename) || !File.exists?(filename))
          fingerprints << {
            :size => File.size(filename),
            :sha1 => Digest::SHA1.file(filename).hexdigest,
            :fn => filename
          }
          total_size += File.size(filename)
        end

        # Check to see if the resource check is worth the round trip
        if (total_size > (64*1024)) # 64k for now
          # Send resource fingerprints to the cloud controller
          appcloud_resources = client.check_resources(fingerprints)
        end
        display 'OK'.green

        if appcloud_resources
          display '  Processing resources: ', false
          # We can then delete what we do not need to send.
          appcloud_resources.each do |resource|
            FileUtils.rm_f resource[:fn]
            # adjust filenames sans the explode_dir prefix
            resource[:fn].sub!("#{explode_dir}/", '')
          end
          display 'OK'.green
        end

      end

      # If no resource needs to be sent, add an empty file to ensure we have
      # a multi-part request that is expected by nginx fronting the CC.
      if VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?
        Dir.chdir(explode_dir) do
          File.new(".__empty__", "w")
        end
      end
      # Perform Packing of the upload bits here.
      display '  Packing application: ', false
      VMC::Cli::ZipUtil.pack(explode_dir, upload_file)
      display 'OK'.green

      upload_size = File.size(upload_file);
      if upload_size > 1024*1024
        upload_size  = (upload_size/(1024.0*1024.0)).round.to_s + 'M'
      elsif upload_size > 0
        upload_size  = (upload_size/1024.0).round.to_s + 'K'
      else
        upload_size = '0K'
      end

      upload_str = "  Uploading (#{upload_size}): "
      display upload_str, false

      FileWithPercentOutput.display_str = upload_str
      FileWithPercentOutput.upload_size = File.size(upload_file);
      file = FileWithPercentOutput.open(upload_file, 'rb')

      client.upload_app(appname, file, appcloud_resources)
      display 'OK'.green if VMC::Cli::ZipUtil.get_files_to_pack(explode_dir).empty?

      display 'Push Status: ', false
      display 'OK'.green

      ensure
        # Cleanup if we created an exploded directory.
        FileUtils.rm_f(upload_file) if upload_file
        FileUtils.rm_rf(explode_dir) if explode_dir
    end

    def check_app_limit
      usage = client_info[:usage]
      limits = client_info[:limits]
      return unless usage and limits and limits[:apps]
      if limits[:apps] == usage[:apps]
        display "Not enough capacity for operation.".red
        tapps = limits[:apps] || 0
        apps  = usage[:apps] || 0
        err "Current Usage: (#{apps} of #{tapps} total apps already in use)"
      end
    end

    def check_has_capacity_for(mem_wanted)
      usage = client_info[:usage]
      limits = client_info[:limits]
      return unless usage and limits
      available_for_use = limits[:memory].to_i - usage[:memory].to_i
      if mem_wanted > available_for_use
        tmem = pretty_size(limits[:memory]*1024*1024)
        mem  = pretty_size(usage[:memory]*1024*1024)
        display "Not enough capacity for operation.".yellow
        available = pretty_size(available_for_use * 1024 * 1024)
        err "Current Usage: (#{mem} of #{tmem} total, #{available} available for use)"
      end
    end

    def mem_choices
      default = ['64M', '128M', '256M', '512M', '1G', '2G']

      return default unless client_info
      return default unless (usage = client_info[:usage] and limits = client_info[:limits])

      available_for_use = limits[:memory].to_i - usage[:memory].to_i
      check_has_capacity_for(64) if available_for_use < 64
      return ['64M'] if available_for_use < 128
      return ['64M', '128M'] if available_for_use < 256
      return ['64M', '128M', '256M'] if available_for_use < 512
      return ['64M', '128M', '256M', '512M'] if available_for_use < 1024
      return ['64M', '128M', '256M', '512M', '1G'] if available_for_use < 2048
      return ['64M', '128M', '256M', '512M', '1G', '2G']
    end

    def normalize_mem(mem)
      return mem if /K|G|M/i =~ mem
      "#{mem}M"
    end

    def mem_choice_to_quota(mem_choice)
      (mem_choice =~ /(\d+)M/i) ? mem_quota = $1.to_i : mem_quota = mem_choice.to_i * 1024
      mem_quota
    end

    def mem_quota_to_choice(mem)
      if mem < 1024
        mem_choice = "#{mem}M"
      else
        mem_choice = "#{(mem/1024).to_i}G"
      end
      mem_choice
    end

    def get_instances(appname)
      instances_info_envelope = client.app_instances(appname)
      # Empty array is returned if there are no instances running.
      instances_info_envelope = {} if instances_info_envelope.is_a?(Array)

      instances_info = instances_info_envelope[:instances] || []
      instances_info = instances_info.sort {|a,b| a[:index] - b[:index]}

      return display JSON.pretty_generate(instances_info) if @options[:json]

      return display "No running instances for [#{appname}]".yellow if instances_info.empty?

      instances_table = table do |t|
        show_debug = instances_info.any? { |e| e[:debug_port] }

        headings = ['Index', 'State', 'Start Time']
        headings << 'Debug IP' if show_debug
        headings << 'Debug Port' if show_debug

        t.headings = headings

        instances_info.each do |entry|
          row = [entry[:index], entry[:state], Time.at(entry[:since]).strftime("%m/%d/%Y %I:%M%p")]
          row << entry[:debug_ip] if show_debug
          row << entry[:debug_port] if show_debug
          t << row
        end
      end
      display "\n"
      display instances_table
    end

    def change_instances(appname, instances)
      app = client.app_info(appname)

      match = instances.match(/([+-])?\d+/)
      err "Invalid number of instances '#{instances}'" unless match

      instances = instances.to_i
      current_instances = app[:instances]
      new_instances = match.captures[0] ? current_instances + instances : instances
      err "There must be at least 1 instance." if new_instances < 1

      if current_instances == new_instances
        display "Application [#{appname}] is already running #{new_instances} instance#{'s' if new_instances > 1}.".yellow
        return
      end

      up_or_down = new_instances > current_instances ? 'up' : 'down'
      display "Scaling Application instances #{up_or_down} to #{new_instances}: ", false
      app[:instances] = new_instances
      client.update_app(appname, app)
      display 'OK'.green
    end

    def health(d)
      return 'N/A' unless (d and d[:state])
      return 'STOPPED' if d[:state] == 'STOPPED'

      healthy_instances = d[:runningInstances]
      expected_instance = d[:instances]
      health = nil

      if d[:state] == "STARTED" && expected_instance > 0 && healthy_instances
        health = format("%.3f", healthy_instances.to_f / expected_instance).to_f
      end

      return 'RUNNING' if health && health == 1.0
      return "#{(health * 100).round}%" if health
      return 'N/A'
    end

    def app_started_properly(appname, error_on_health)
      app = client.app_info(appname)
      case health(app)
        when 'N/A'
          # Health manager not running.
          err "\nApplication '#{appname}'s state is undetermined, not enough information available." if error_on_health
          return false
        when 'RUNNING'
          return true
        else
          if app[:meta][:debug] == "suspend"
            display "\nApplication [#{appname}] has started in a mode that is waiting for you to trigger startup."
            return true
          else
            return false
          end
      end
    end

    def display_logfile(path, content, instance='0', banner=nil)
      banner ||= "====> #{path} <====\n\n"

      unless content.empty?
        display banner
        prefix = "[#{instance}: #{path}] -".bold if @options[:prefixlogs]
        unless prefix
          display content
        else
          lines = content.split("\n")
          lines.each { |line| display "#{prefix} #{line}"}
        end
        display ''
      end
    end

    def grab_all_logs(appname)
      instances_info_envelope = client.app_instances(appname)
      return if instances_info_envelope.is_a?(Array)
      instances_info = instances_info_envelope[:instances] || []
      instances_info.each do |entry|
        grab_logs(appname, entry[:index])
      end
    end

    def grab_logs(appname, instance)
      files_under(appname, instance, "/logs").each do |path|
        begin
          content = client.app_files(appname, path, instance)
          display_logfile(path, content, instance)
        rescue VMC::Client::NotFound, VMC::Client::TargetError
        end
      end
    end

    def files_under(appname, instance, path)
      client.app_files(appname, path, instance).split("\n").collect do |l|
        "#{path}/#{l.split[0]}"
      end
    rescue VMC::Client::NotFound, VMC::Client::TargetError
      []
    end

    def grab_crash_logs(appname, instance, was_staged=false)
      # stage crash info
      crashes(appname, false) unless was_staged

      instance ||= '0'
      map = VMC::Cli::Config.instances
      instance = map[instance] if map[instance]

      (files_under(appname, instance, "/logs") +
        files_under(appname, instance, "/app/logs") +
        files_under(appname, instance, "/app/log")).each do |path|
        content = client.app_files(appname, path, instance)
        display_logfile(path, content, instance)
      end
    end

    def grab_startup_tail(appname, since = 0)
      new_lines = 0
      path = "logs/startup.log"
      content = client.app_files(appname, path)
      if content && !content.empty?
        display "\n==== displaying startup log ====\n\n" if since == 0
        response_lines = content.split("\n")
        lines = response_lines.size
        tail = response_lines[since, lines] || []
        new_lines = tail.size
        display tail.join("\n") if new_lines > 0
      end
      since + new_lines
    rescue VMC::Client::NotFound, VMC::Client::TargetError
      0
    end

    def provisioned_services_apps_hash
      apps = client.apps
      services_apps_hash = {}
      apps.each {|app|
        app[:services].each { |svc|
          svc_apps = services_apps_hash[svc]
          unless svc_apps
            svc_apps = Set.new
            services_apps_hash[svc] = svc_apps
          end
          svc_apps.add(app[:name])
        } unless app[:services] == nil
      }
      services_apps_hash
    end

    def delete_app(appname, force)
      app = client.app_info(appname)
      services_to_delete = []
      app_services = app[:services]
      services_apps_hash = provisioned_services_apps_hash
      app_services.each { |service|
        del_service = force && no_prompt
        unless no_prompt || force
          del_service = ask(
            "Provisioned service [#{service}] detected, would you like to delete it?",
            :default => false
          )

          if del_service
            apps_using_service = services_apps_hash[service].reject!{ |app| app == appname}
            if apps_using_service.size > 0
              del_service = ask(
                "Provisioned service [#{service}] is also used by #{apps_using_service.size == 1 ? "app" : "apps"} #{apps_using_service.entries}, are you sure you want to delete it?",
                :default => false
              )
            end
          end
        end
        services_to_delete << service if del_service
      }

      display "Deleting application [#{appname}]: ", false
      client.delete_app(appname)
      display 'OK'.green

      services_to_delete.each do |s|
        delete_service_banner(s)
      end
    end

    def do_start(appname, push=false)
      app = client.app_info(appname)
      return display "Application '#{appname}' could not be found".red if app.nil?
      return display "Application '#{appname}' already started".yellow if app[:state] == 'STARTED'



      if @options[:debug]
        runtimes = client.runtimes_info
        return display "Cannot get runtime information." unless runtimes

        runtime = runtimes[app[:staging][:stack].to_sym]
        return display "Unknown runtime." unless runtime

        unless runtime[:debug_modes] and runtime[:debug_modes].include? @options[:debug]
          modes = runtime[:debug_modes] || []

          display "\nApplication '#{appname}' cannot start in '#{@options[:debug]}' mode"

          if push
            display "Try 'vmc start' with one of the following modes: #{modes.inspect}"
          else
            display "Available modes: #{modes.inspect}"
          end

          return
        end
      end

      banner = "Staging Application '#{appname}': "
      display banner, false

      t = Thread.new do
        count = 0
        while count < TAIL_TICKS do
          display '.', false
          sleep SLEEP_TIME
          count += 1
        end
      end

      app[:state] = 'STARTED'
      app[:debug] = @options[:debug]
      app[:console] = VMC::Cli::Framework.lookup_by_framework(app[:staging][:model]).console
      client.update_app(appname, app)

      Thread.kill(t)
      clear(LINE_LENGTH)
      display "#{banner}#{'OK'.green}"

      banner = "Starting Application '#{appname}': "
      display banner, false

      count = log_lines_displayed = 0
      failed = false
      start_time = Time.now.to_i

      loop do
        display '.', false unless count > TICKER_TICKS
        sleep SLEEP_TIME

        break if app_started_properly(appname, count > HEALTH_TICKS)

        if !crashes(appname, false, start_time).empty?
          # Check for the existance of crashes
          display "\nError: Application [#{appname}] failed to start, logs information below.\n".red
          grab_crash_logs(appname, '0', true)
          if push and !no_prompt
            display "\n"
            delete_app(appname, false) if ask "Delete the application?", :default => true
          end
          failed = true
          break
        elsif count > TAIL_TICKS
          log_lines_displayed = grab_startup_tail(appname, log_lines_displayed)
        end

        count += 1
        if count > GIVEUP_TICKS # 2 minutes
          display "\nApplication is taking too long to start, check your logs".yellow
          break
        end
      end
      exit(false) if failed
      clear(LINE_LENGTH)
      display "#{banner}#{'OK'.green}"
    end

    def do_stop(appname)
      app = client.app_info(appname)
      return display "Application '#{appname}' already stopped".yellow if app[:state] == 'STOPPED'
      display "Stopping Application '#{appname}': ", false
      app[:state] = 'STOPPED'
      client.update_app(appname, app)
      display 'OK'.green
    end

    def do_push(appname=nil)
      unless @app_info || no_prompt
        @manifest = { "applications" => { @path => { "name" => appname } } }

        interact

        if ask("Would you like to save this configuration?", :default => false)
          save_manifest
        end

        resolve_manifest(@manifest)

        @app_info = @manifest["applications"][@path]
      end

      instances = info(:instances, 1)
      exec = info(:exec, 'thin start')

      ignore_framework = @options[:noframework]
      no_start = @options[:nostart]

      appname ||= info(:name)
      url = info(:url) || info(:urls)
      mem, memswitch = nil, info(:mem)
      memswitch = normalize_mem(memswitch) if memswitch
      command = info(:command)
      runtime = info(:runtime)

      # Check app existing upfront if we have appname
      app_checked = false
      if appname
        err "Application '#{appname}' already exists, use update" if app_exists?(appname)
        app_checked = true
      else
        raise VMC::Client::AuthError unless client.logged_in?
      end

      # check if we have hit our app limit
      check_app_limit
      # check memsize here for capacity
      if memswitch && !no_start
        check_has_capacity_for(mem_choice_to_quota(memswitch) * instances)
      end

      appname ||= ask("Application Name") unless no_prompt
      err "Application Name required." if appname.nil? || appname.empty?

      check_deploy_directory(@application)

      if !app_checked and app_exists?(appname)
        err "Application '#{appname}' already exists, use update or delete."
      end

      if ignore_framework
        framework = VMC::Cli::Framework.new
      elsif f = info(:framework)
        info = Hash[f["info"].collect { |k, v| [k.to_sym, v] }]

        framework = VMC::Cli::Framework.create(f["name"], info)
        exec = framework.exec if framework && framework.exec
      else
        framework = detect_framework(prompt_ok)
      end

      err "Application Type undetermined for path '#{@application}'" unless framework

      if not runtime
        default_runtime = framework.default_runtime @application
        runtime = detect_runtime(default_runtime, !no_prompt) if framework.prompt_for_runtime?
      end
      command = ask("Start Command") if !command && framework.require_start_command?

      default_url = "None"
      default_url = "#{appname}.#{VMC::Cli::Config.suggest_url}" if framework.require_url?


      unless no_prompt || url || !framework.require_url?
        url = ask(
          "Application Deployed URL",
          :default => default_url
        )

        # common error case is for prompted users to answer y or Y or yes or
        # YES to this ask() resulting in an unintended URL of y. Special case
        # this common error
        url = nil if YES_SET.member? url
      end
      url = nil if url == "None"
      default_url = nil if default_url == "None"
      url ||= default_url

      if memswitch
        mem = memswitch
      elsif prompt_ok
        mem = ask("Memory Reservation",
                  :default => framework.memory(runtime),
                  :choices => mem_choices)
      else
        mem = framework.memory runtime
      end

      # Set to MB number
      mem_quota = mem_choice_to_quota(mem)

      # check memsize here for capacity
      check_has_capacity_for(mem_quota * instances) unless no_start

      display 'Creating Application: ', false

      manifest = {
        :name => "#{appname}",
        :staging => {
           :framework => framework.name,
           :runtime => runtime
        },
        :uris => Array(url),
        :instances => instances,
        :resources => {
          :memory => mem_quota
        }
      }
      manifest[:staging][:command] = command if command

      # Send the manifest to the cloud controller
      client.create_app(appname, manifest)
      display 'OK'.green


      existing = Set.new(client.services.collect { |s| s[:name] })

      if @app_info && services = @app_info["services"]
        services.each do |name, info|
          unless existing.include? name
            create_service_banner(info["type"], name, true)
          end

          bind_service_banner(name, appname)
        end
      end

      # Stage and upload the app bits.
      upload_app_bits(appname, @application)

      start(appname, true) unless no_start
    end

    def do_stats(appname)
      stats = client.app_stats(appname)
      return display JSON.pretty_generate(stats) if @options[:json]

      stats_table = table do |t|
        t.headings = 'Instance', 'CPU (Cores)', 'Memory (limit)', 'Disk (limit)', 'Uptime'
        stats.each do |entry|
          index = entry[:instance]
          stat = entry[:stats]
          hp = "#{stat[:host]}:#{stat[:port]}"
          uptime = uptime_string(stat[:uptime])
          usage = stat[:usage]
          if usage
            cpu   = usage[:cpu]
            mem   = (usage[:mem] * 1024) # mem comes in K's
            disk  = usage[:disk]
          end
          mem_quota = stat[:mem_quota]
          disk_quota = stat[:disk_quota]
          mem  = "#{pretty_size(mem)} (#{pretty_size(mem_quota, 0)})"
          disk = "#{pretty_size(disk)} (#{pretty_size(disk_quota, 0)})"
          cpu = cpu ? cpu.to_s : 'NA'
          cpu = "#{cpu}% (#{stat[:cores]})"
          t << [index, cpu, mem, disk, uptime]
        end
      end

      if stats.empty?
        display "No running instances for [#{appname}]".yellow
      else
        display stats_table
      end
    end

    def all_files(appname, path)
      instances_info_envelope = client.app_instances(appname)
      return if instances_info_envelope.is_a?(Array)
      instances_info = instances_info_envelope[:instances] || []
      instances_info.each do |entry|
        begin
          content = client.app_files(appname, path, entry[:index])
          display_logfile(
            path,
            content,
            entry[:index],
            "====> [#{entry[:index]}: #{path}] <====\n".bold
          )
        rescue VMC::Client::NotFound, VMC::Client::TargetError
        end
      end
    end
  end

  class FileWithPercentOutput < ::File
    class << self
      attr_accessor :display_str, :upload_size
    end

    def update_display(rsize)
      @read ||= 0
      @read += rsize
      p = (@read * 100 / FileWithPercentOutput.upload_size).to_i
      unless VMC::Cli::Config.output.nil? || !STDOUT.tty?
        clear(FileWithPercentOutput.display_str.size + 5)
        VMC::Cli::Config.output.print("#{FileWithPercentOutput.display_str} #{p}%")
        VMC::Cli::Config.output.flush
      end
    end

    def read(*args)
      result  = super(*args)
      if result && result.size > 0
        update_display(result.size)
      else
        unless VMC::Cli::Config.output.nil? || !STDOUT.tty?
          clear(FileWithPercentOutput.display_str.size + 5)
          VMC::Cli::Config.output.print(FileWithPercentOutput.display_str)
          display('OK'.green)
        end
      end
      result
    end
  end

end
