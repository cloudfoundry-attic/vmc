require 'spec_helper'

describe 'VMC::Cli::ConsoleHelper' do

  include VMC::Cli::ConsoleHelper

  before(:each) do
    @client = mock("client")
    @telnet_client = mock("telnet_client")
  end

  it 'should return connection info for apps that have a console ip and port' do
    @client.should_receive(:app_info).with("foo").and_return(:staging=>{:model=>'rails3'})
    @client.should_receive(:app_instances).with("foo").and_return({:instances=>[{:console_ip=>'192.168.1.1', :console_port=>3344}]})
    console_connection_info('foo').should == {'hostname'=>'192.168.1.1','port'=>3344}
  end

  it 'should output a message when no app instances found' do
    @client.should_receive(:app_info).with("foo").and_return(:staging=>{:model=>'rails3'})
    @client.should_receive(:app_instances).with("foo").and_return({:instances=>[]})
    errmsg = nil
    begin
      console_connection_info('foo')
    rescue VMC::Cli::CliExit=>e
      errmsg = e.message
    end
    errmsg.should == "Error: No running instances for [foo]"
  end

  it 'should output a message when app does not have console access b/c files are missing' do
    @client.should_receive(:app_info).with("foo").and_return(:staging=>{:model=>'rails3'})
    @client.should_receive(:app_instances).with("foo").and_return({:instances=>[{}]})
    @client.should_receive(:app_files).with('foo','/app/cf-rails-console').and_raise(VMC::Client::TargetError)
    errmsg = nil
    begin
      console_connection_info('foo')
    rescue VMC::Cli::CliExit=>e
      errmsg = e.message
    end
    errmsg.should == "Error: Console access not supported for [foo]. " +
      "Please redeploy your app to enable support."
  end

  it 'should output a message when app does not have console access b/c port is not bound' do
    @client.should_receive(:app_info).with("foo").and_return(:staging=>{:model=>'rails3'})
    @client.should_receive(:app_instances).with("foo").and_return({:instances=>[{}]})
    @client.should_receive(:app_files).with('foo','/app/cf-rails-console').and_return("files")
    errmsg = nil
    begin
      console_connection_info('foo')
    rescue VMC::Cli::CliExit=>e
      errmsg = e.message
    end
    errmsg.should == "Error: Console port not provided for [foo].  Try restarting the app."
  end

  it 'should output a message when console is not supported for app type' do
     @client.should_receive(:app_info).with("foo").and_return(:staging=>{:model=>'sinatra'})
     errmsg = nil
     begin
       console_connection_info('foo')
     rescue VMC::Cli::CliExit=>e
       errmsg = e.message
     end
     errmsg.should == "Error: 'foo' is a sinatra application.  " +
       "Console access is not supported for sinatra applications."
  end

  it 'should start console and process a command if authentication succeeds' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("Switch to inspect mode\nirb():001:0> ")
    verify_console_exit "irb():001:0> "
    start_local_console(3344,'foo')
  end

  it 'should output a message if console authentication information cannot be obtained' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('invalid_console_access.txt')))
    errmsg = nil
    begin
      start_local_console(3344,'foo')
    rescue VMC::Cli::CliExit=>e
      errmsg = e.message
    end
    errmsg.should == "Error: Unable to verify console credentials."
  end

  it 'should exit if authentication fails' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("Login failed.")
    @telnet_client.should_receive(:close)
    errmsg = nil
    begin
      start_local_console(3344,'foo')
    rescue VMC::Cli::CliExit=>e
      errmsg = e.message
    end
    errmsg.should == "Error: Login failed."
  end

  it 'should retry authentication on timeout' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_raise(TimeoutError)
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("Switch to inspect mode\nirb():001:0> ")
    verify_console_exit "irb():001:0> "
    start_local_console(3344,'foo')
  end

  it 'should retry authentication on EOF' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_raise(EOFError)
    @telnet_client.should_receive(:close)
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("irb():001:0> ")
    verify_console_exit "irb():001:0> "
    start_local_console(3344,'foo')
  end

  it 'should operate console interactively' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("irb():001:0> ")
    Readline.should_receive(:readline).with("irb():001:0> ").and_return("puts 'hi'")
    Readline::HISTORY.should_receive(:push).with("puts 'hi'")
    @telnet_client.should_receive(:cmd).with("puts 'hi'").and_return("nil" + "\n" + "irb():002:0> ")
    verify_console_exit "irb():002:0> "
    start_local_console(3344,'foo')
  end

  it 'should not crash if command times out' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("irb():001:0> ")
    Readline.should_receive(:readline).with("irb():001:0> ").and_return("puts 'hi'")
    Readline::HISTORY.should_receive(:push).with("puts 'hi'")
    @telnet_client.should_receive(:cmd).with("puts 'hi'").and_raise(TimeoutError)
    verify_console_exit "irb():001:0> "
    start_local_console(3344,'foo')
  end

  it 'should exit with error message if an EOF is received' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("Switch to inspect mode\nirb():001:0> ")
    Readline.should_receive(:readline).with("irb():001:0> ").and_return("puts 'hi'")
    Readline::HISTORY.should_receive(:push).with("puts 'hi'")
    @telnet_client.should_receive(:cmd).with("puts 'hi'").and_raise(EOFError)
    errmsg = nil
    begin
      start_local_console(3344,'foo')
    rescue VMC::Cli::CliExit=>e
      errmsg = e.message
    end
    errmsg.should == "Error: The console connection has been terminated.  " +
      "Perhaps the app was stopped or deleted?"
  end

  it 'should not keep blank lines in history' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("irb():001:0> ")
    Readline.should_receive(:readline).with("irb():001:0> ").and_return("")
    Readline::HISTORY.should_not_receive(:push).with("")
    @telnet_client.should_receive(:cmd).with("").and_return("irb():002:0*> ")
    verify_console_exit "irb():002:0*> "
    start_local_console(3344,'foo')
  end

  it 'should not keep identical commands in history' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("irb():001:0> ")
    Readline.should_receive(:readline).with("irb():001:0> ").and_return("puts 'hi'")
    Readline::HISTORY.should_receive(:to_a).and_return(["puts 'hi'"])
    Readline::HISTORY.should_not_receive(:push).with("puts 'hi'")
    @telnet_client.should_receive(:cmd).with("puts 'hi'").and_return("nil" + "\n" + "irb():002:0> ")
    verify_console_exit "irb():002:0> "
    start_local_console(3344,'foo')
  end

  it 'should return remote tab completion data' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("Switch to inspect mode\nirb():001:0> ")
    @telnet_client.should_receive(:cmd).with({"String"=>"app.\t", "Match"=>/\S*\n$/, "Timeout"=>10}).and_return("to_s,nil?\n")
    verify_console_exit "irb():001:0> "
    start_local_console(3344,'foo')
    Readline.completion_proc.yield("app.").should == ["to_s","nil?"]
  end

  it 'should return remote tab completion data on receipt of empty completion string' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("irb():001:0> ")
    @telnet_client.should_receive(:cmd).with({"String"=>"app.\t", "Match"=>/\S*\n$/, "Timeout"=>10}).and_return("\n")
    verify_console_exit "irb():001:0> "
    start_local_console(3344,'foo')
    Readline.completion_proc.yield("app.").should == []
  end

  it 'should not crash on timeout of remote tab completion data' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("Switch to inspect mode\nirb():001:0> ")
    @telnet_client.should_receive(:cmd).with({"String"=>"app.\t", "Match"=>/\S*\n$/, "Timeout"=>10}).and_raise(TimeoutError)
    verify_console_exit "irb():001:0> "
    start_local_console(3344,'foo')
    Readline.completion_proc.yield("app.").should == []
  end

  it 'should properly initialize Readline for tab completion' do
    @client.should_receive(:app_files).with("foo", '/app/cf-rails-console/.consoleaccess', '0').and_return(IO.read(spec_asset('console_access.txt')))
    @telnet_client.should_receive(:login).with({"Name"=>"cfuser", "Password"=>"testpw"}).and_return("irb():001:0> ")
    Readline.should_receive(:respond_to?).with("basic_word_break_characters=").and_return(true)
    Readline.should_receive(:basic_word_break_characters=).with(" \t\n`><=;|&{(")
    Readline.should_receive(:completion_append_character=).with(nil)
    Readline.should_receive(:completion_proc=)
    verify_console_exit "irb():001:0> "
    start_local_console(3344,'foo')
  end

  def client(cli=nil)
    @client
  end

  def display(message, nl=true)
  end

  def telnet_client(port)
    @telnet_client
  end

  def verify_console_exit(prompt)
    Readline.should_receive(:readline).with(prompt).and_return("exit")
    @telnet_client.should_receive(:cmd).with(({"String"=>"exit", "Timeout"=>1})).and_raise(TimeoutError)
    @telnet_client.should_receive(:close)
  end
end