require 'spec_helper'
require 'tmpdir'

describe 'VMC::Cli::Framework' do

  before(:each) do
    VMC::Cli::Config.nozip = true
  end

  it 'should be able to detect a Java web app war' do
    app = spec_asset('java_web')
    framework(app).should =~ /Java Web/
  end

  it 'should be able to detect an exploded Java web app' do
    war_file = spec_asset('java_web/java_web.war')
    framework(war_file, true).should =~ /Java Web/
  end

  it 'should be able to detect a Spring web app war' do
    app = spec_asset('spring')
    framework(app).should =~ /Spring/
  end

  it 'should be able to detect an exploded Spring web app' do
    war_file = spec_asset('spring/spring.war')
    framework(war_file, true).should =~ /Spring/
  end

  it 'should be able to detect a Spring web app war that uses OSGi-style jars' do
    app = spec_asset('spring-osgi')
    framework(app).should =~ /Spring/
  end

  it 'should be able to detect an exploded Spring web app that uses OSGi-style jars' do
    war_file = spec_asset('spring-osgi/spring-osgi.war')
    framework(war_file, true).should =~ /Spring/
  end

  it 'should be able to detect a Lift web app war' do
    app = spec_asset('lift')
    framework(app).should =~ /Lift/
  end

  it 'should be able to detect an exploded Lift web app' do
    war_file = spec_asset('lift/lift.war')
    framework(war_file, true).should =~ /Lift/
  end

  it 'should be able to detect a Grails web app war' do
    app = spec_asset('grails')
    framework(app).should =~ /Grails/
  end

  it 'should be able to detect an exploded Grails web app' do
    war_file = spec_asset('grails/grails.war')
    framework(war_file, true).should =~ /Grails/
  end

  it 'should be able to detect a Rails3 app' do
    app = spec_asset('rails3')
    framework(app).should =~ /Rails/
  end

  it 'should be able to detect a Sinatra app' do
    app = spec_asset('sinatra')
    framework(app).should =~ /Sinatra/
  end

  it 'should be able to detect a Node.js app' do
    app = spec_asset('node')
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
end
