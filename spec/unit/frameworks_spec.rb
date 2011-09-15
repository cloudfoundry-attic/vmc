require 'spec_helper'
require 'tmpdir'

describe 'VMC::Cli::Framework' do

  before(:each) do
    VMC::Cli::Config.nozip = true
  end

  it 'should be able to detect a Java web app war' do
    app = spec_asset('tests/java_web/java_tiny_app/target')
    framework(app).should =~ /Java Web/
  end

  it 'should be able to detect an exploded Java web app' do
    app = spec_asset('tests/java_web/java_tiny_app/target')
    framework(get_war_file(app), true).should =~ /Java Web/
  end

  it 'should be able to detect a Spring web app war' do
    app = spec_asset('tests/spring/roo-guestbook/target')
    framework(app).should =~ /Spring/
  end

  it 'should be able to detect an exploded Spring web app' do
    app = spec_asset('tests/spring/roo-guestbook/target/')
    framework(get_war_file(app), true).should =~ /Spring/
  end

  it 'should be able to detect a Spring web app war that uses OSGi-style jars' do
    app = spec_asset('tests/spring/spring-osgi-hello/target')
    framework(app).should =~ /Spring/
  end

  it 'should be able to detect an exploded Spring web app that uses OSGi-style jars' do
    app = spec_asset('tests/spring/spring-osgi-hello/target')
    framework(get_war_file(app), true).should =~ /Spring/
  end

  it 'should be able to detect a Lift web app war' do
    app = spec_asset('tests/lift/hello_lift/target')
    framework(app).should =~ /Lift/
  end

  it 'should be able to detect an exploded Lift web app' do
    app = spec_asset('tests/lift/hello_lift/target')
    framework(get_war_file(app), true).should =~ /Lift/
  end

  it 'should be able to detect a Grails web app war' do
    pending "Availability of a fully functional maven plugin for grails"
    app = spec_asset('tests/grails/guestbook/target')
    framework(app).should =~ /Grails/
  end

  it 'should be able to detect an exploded Grails web app' do
    pending "Availability of a fully functional maven plugin for grails"
    app = spec_asset('tests/grails/guestbook/target')
    framework(get_war_file(app), true).should =~ /Grails/
  end

  it 'should be able to detect a Rails3 app' do
    app = spec_asset('tests/rails3/hello_vcap')
    framework(app).should =~ /Rails/
  end

  it 'should be able to detect a Sinatra app' do
    app = spec_asset('tests/sinatra/hello_vcap')
    framework(app).should =~ /Sinatra/
  end

  it 'should be able to detect a Node.js app' do
    app = spec_asset('tests/node/hello_vcap')
    framework(app).should=~ /Node.js/
  end

  def framework app, explode=false
    unless explode == true
      return VMC::Cli::Framework.detect(app).to_s
    end
    Dir.mktmpdir {|dir|
      exploded_dir = File.join(dir, "exploded")
      VMC::Cli::ZipUtil.unpack(app, exploded_dir)
      VMC::Cli::Framework.detect(exploded_dir).to_s
    }
  end

  def get_war_file app
    Dir.chdir(app)
    war_file = Dir.glob('*.war').first
  end
end
