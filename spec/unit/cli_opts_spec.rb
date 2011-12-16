require 'spec_helper'

describe 'VMC::Cli::Runner' do

  it 'should parse email and password correctly' do
    args = "--email derek@gmail.com --password foo"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options.should have(3).items
    cli.options.should have_key :email
    cli.options[:email].should == 'derek@gmail.com'
    cli.options[:password].should == 'foo'
  end

  it 'should parse multiple variations of password' do
    args = "--password foo"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:password].should == 'foo'

    args = "--pass foo"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:password].should == 'foo'

    args = "--passwd foo"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:password].should == 'foo'
  end

  it 'should parse name and bind args correctly' do
    args = "--name foo --bind bar"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:name].should == 'foo'
    cli.options[:bind].should == 'bar'
  end

  it 'should parse instances and instance into a number and string' do
    args = "--instances 1 --instance 2"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:instances].should == 1
    cli.options[:instance].should == "2"
  end

  it 'should parse url, mem, path correctly' do
    args = "--mem 64 --url http://foo.vcap.me --path ~derek"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:mem].should == '64'
    cli.options[:url].should == 'http://foo.vcap.me'
    cli.options[:path].should == '~derek'
  end

  it 'should parse multiple forms of nostart correctly' do
    cli = VMC::Cli::Runner.new().parse_options!
    cli.options[:nostart].should_not be
    args = "--nostart"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:nostart].should be_true
    args = "--no-start"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:nostart].should be_true
  end

  it 'should parse force and all correctly' do
    args = "--force --all"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:force].should be_true
    cli.options[:all].should be_true
  end

  it 'should parse debug correctly' do
    cli = VMC::Cli::Runner.new().parse_options!
    cli.options[:debug].should_not be
    args = "--debug"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:debug].should == 'run'
    args = "--debug suspend"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:debug].should == 'suspend'
    args = "-d"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:debug].should == 'run'
    args = "-d suspend"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:debug].should == 'suspend'
  end

  it 'should parse manifest override correctly' do
    cli = VMC::Cli::Runner.new().parse_options!
    cli.options[:manifest].should_not be
    args = "--manifest foo"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:manifest].should == 'foo'
    args = "-m foo"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:manifest].should == 'foo'
  end

  it 'should parse token override correctly' do
    cli = VMC::Cli::Runner.new().parse_options!
    cli.options[:token_file].should_not be
    args = "--token-file /tmp/foobar"
    cli = VMC::Cli::Runner.new(args.split).parse_options!
    cli.options[:token_file].should ==  '/tmp/foobar'
  end

end
