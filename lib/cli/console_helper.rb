require 'net/telnet'
require 'readline'

module VMC::Cli
  module ConsoleHelper

    def console_connection_info(appname)
      app = client.app_info(appname)
      fw = VMC::Cli::Framework.lookup_by_framework(app[:staging][:model])
      if !fw.console
        err "'#{appname}' is a #{fw.name} application.  " +
          "Console access is not supported for #{fw.name} applications."
      end
      instances_info_envelope = client.app_instances(appname)
      instances_info_envelope = {} if instances_info_envelope.is_a?(Array)

      instances_info = instances_info_envelope[:instances] || []
      err "No running instances for [#{appname}]" if instances_info.empty?

      entry = instances_info[0]
      if !entry[:console_port]
        begin
          client.app_files(appname, '/app/cf-rails-console')
          err "Console port not provided for [#{appname}].  Try restarting the app."
        rescue VMC::Client::TargetError, VMC::Client::NotFound
          err "Console access not supported for [#{appname}]. " +
            "Please redeploy your app to enable support."
        end
      end
      conn_info = {'hostname' => entry[:console_ip], 'port' => entry[:console_port]}
    end

    def start_local_console(port, appname)
      auth_info = console_credentials(appname)
      display "Connecting to '#{appname}' console: ", false
      prompt = console_login(auth_info, port)
      display "OK".green
      display "\n"
      initialize_readline
      run_console prompt
    end

    def console_login(auth_info, port)
      if !auth_info["username"] || !auth_info["password"]
        err "Unable to verify console credentials."
      end
      @telnet_client = telnet_client(port)
      prompt = nil
      err_msg = "Login attempt timed out."
      5.times do
        begin
          results = @telnet_client.login("Name"=>auth_info["username"],
            "Password"=>auth_info["password"])
          lines = results.sub("Login: Password: ", "").split("\n")
          last_line = lines.pop
          if last_line =~ /[$%#>] \z/n
            prompt = last_line
          elsif last_line =~ /Login failed/
            err_msg = last_line
          end
          break
        rescue TimeoutError
          sleep 1
        rescue EOFError
          #This may happen if we login right after app starts
          close_console
          sleep 5
          @telnet_client = telnet_client(port)
        end
        display ".", false
      end
      unless prompt
        close_console
        err err_msg
      end
      prompt
    end

    def send_console_command(cmd)
      results = @telnet_client.cmd(cmd)
      results.split("\n")
    end

    def console_credentials(appname)
      content = client.app_files(appname, '/app/cf-rails-console/.consoleaccess', '0')
      YAML.load(content)
    end

    def close_console
      @telnet_client.close
    end

    def console_tab_completion_data(cmd)
      begin
        results = @telnet_client.cmd("String"=> cmd + "\t", "Match"=>/\S*\n$/, "Timeout"=>10)
        results.chomp.split(",")
      rescue TimeoutError
        [] #Just return empty results if timeout occurred on tab completion
      end
    end

    private
    def telnet_client(port)
      Net::Telnet.new({"Port"=>port, "Prompt"=>/[$%#>] \z|Login failed/n, "Timeout"=>30, "FailEOF"=>true})
    end

    def readline_with_history(prompt)
      line = Readline::readline(prompt)
      return nil if line == nil || line == 'quit' || line == 'exit'
      Readline::HISTORY.push(line) if not line =~ /^\s*$/ and Readline::HISTORY.to_a[-1] != line
      line
    end

    def run_console(prompt)
      prev = trap("INT")  { |x| exit_console; prev.call(x); exit }
      prev = trap("TERM") { |x| exit_console; prev.call(x); exit }
      loop do
        cmd = readline_with_history(prompt)
        if(cmd == nil)
          exit_console
          break
        end
        prompt = send_console_command_display_results(cmd, prompt)
      end
    end

    def exit_console
      #TimeoutError expected, as exit doesn't return anything
      @telnet_client.cmd("String"=>"exit","Timeout"=>1) rescue TimeoutError
      close_console
    end

    def send_console_command_display_results(cmd, prompt)
      begin
        lines = send_console_command cmd
        #Assumes the last line is a prompt
        prompt = lines.pop
        lines.each {|line| display line if line != cmd}
      rescue TimeoutError
        display "Timed out sending command to server.".red
      rescue EOFError
        err "The console connection has been terminated.  Perhaps the app was stopped or deleted?"
      end
      prompt
    end

    def initialize_readline
      if Readline.respond_to?("basic_word_break_characters=")
        Readline.basic_word_break_characters= " \t\n`><=;|&{("
      end
      Readline.completion_append_character = nil
      #Assumes that sending a String ending with tab will return a non-empty
      #String of comma-separated completion options, terminated by a new line
      #For example, "app.\t" might result in "to_s,nil?,etc\n"
      Readline.completion_proc = proc {|s|
        console_tab_completion_data s
      }
    end
  end
end
