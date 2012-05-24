require 'spec_helper'
require 'tmpdir'
require 'rbconfig'

describe 'VMC::Cli::Framework' do

  before(:all) do
    is_windows = RbConfig::CONFIG['host_os'] =~ /mswin|windows|mingw|cygwin/i
    VMC::Cli::Config.nozip = is_windows
  end

  it 'should be able to detect a Java web app war' do
    app = spec_asset('tests/java_web/java_tiny_app/target')
    framework(app).to_s.should =~ /Java Web/
  end

  it 'should be able to detect an exploded Java web app' do
    app = spec_asset('tests/java_web/java_tiny_app/target')
    framework(get_war_file(app), true).to_s.should =~ /Java Web/
  end

  it 'should be able to detect a Spring web app war' do
    app = spec_asset('tests/spring/roo-guestbook/target')
    framework(app).to_s.should =~ /Spring/
  end

  it 'should be able to detect an exploded Spring web app' do
    app = spec_asset('tests/spring/roo-guestbook/target/')
    framework(get_war_file(app), true).to_s.should =~ /Spring/
  end

  it 'should be able to detect a Spring web app war that uses OSGi-style jars' do
    app = spec_asset('tests/spring/spring-osgi-hello/target')
    framework(app).to_s.should =~ /Spring/
  end

  it 'should be able to detect an exploded Spring web app that uses OSGi-style jars' do
    app = spec_asset('tests/spring/spring-osgi-hello/target')
    framework(get_war_file(app), true).to_s.should =~ /Spring/
  end

  it 'should be able to detect a Lift web app war' do
    app = spec_asset('tests/lift/hello_lift/target')
    framework(app).to_s.should =~ /Lift/
  end

  it 'should be able to detect a Lift web app war file' do
    app = spec_asset('tests/lift/hello_lift/target/scala_lift-1.0.war')
    framework(app).to_s.should =~ /Lift/
  end

  it 'should be able to detect an exploded Lift web app' do
    app = spec_asset('tests/lift/hello_lift/target')
    framework(get_war_file(app), true).to_s.should =~ /Lift/
  end

  it 'should be able to detect a Grails web app war' do
    pending "Availability of a fully functional maven plugin for grails"
    app = spec_asset('tests/grails/guestbook/target')
    framework(app).to_s.should =~ /Grails/
  end

  it 'should be able to detect an exploded Grails web app' do
    pending "Availability of a fully functional maven plugin for grails"
    app = spec_asset('tests/grails/guestbook/target')
    framework(get_war_file(app), true).to_s.should =~ /Grails/
  end

  it 'should be able to detect a Rails3 app' do
    app = spec_asset('tests/rails3/hello_vcap')
    framework(app).to_s.should =~ /Rails/
  end

  it 'should be able to detect a Sinatra app' do
    app = spec_asset('tests/sinatra/hello_vcap')
    framework(app).to_s.should =~ /Sinatra/
  end

  it 'should be able to detect a Rack app' do
    app = spec_asset('tests/rack/app_rack_service')
    framework(app,false,[["rack"]]).to_s.should =~ /Rack/
  end

  it 'should fall back to Sinatra detection if Rack framework not supported' do
    app = spec_asset('tests/rack/app_rack_service')
    framework(app,false).to_s.should =~ /Sinatra/
  end

  it 'should be able to detect a Node.js app' do
    app = spec_asset('tests/node/hello_vcap')
    framework(app).to_s.should=~ /Node.js/
  end

  it 'should be able to detect a Play app' do
    VMC::Cli::Framework.detect_framework_from_zip_contents("lib/play.play_2.9.1-2.1-SNAPSHOT.jar",
      [["play"],["standalone"]])
  end

  it 'should return correct list of available frameworks' do
    VMC::Cli::Framework.known_frameworks([["standalone"],["rails3"]]).should == ["Rails","Standalone"]
  end

  describe 'standalone app support' do
    it 'should fall back to Standalone app from single non-WAR file' do
      app = spec_asset("tests/standalone/java_app/target/" +
        "standalone-java-app-1.0.0.BUILD-SNAPSHOT.jar")
      framework(app,false,[["standalone"]]).to_s.should=~ /Standalone/
    end

    it 'should fall back to nil if Standalone framework not supported for single non-WAR file' do
      app = spec_asset("tests/standalone/java_app/target/" +
        "standalone-java-app-1.0.0.BUILD-SNAPSHOT.jar")
      framework(app).should == nil
    end

    it 'should detect Standalone app from single zip file' do
      app = spec_asset("tests/standalone/java_app/target/zip/" +
        "standalone-java-app-1.0.0.BUILD-SNAPSHOT-jar.zip")
      framework(app,false,[["standalone"],["play"]]).to_s.should=~ /Standalone/
    end

    it 'should detect Standalone app from dir containing a single zip file' do
      app = spec_asset("tests/standalone/java_app/target/zip/")
      framework(app,false,[["standalone"],["play"]]).to_s.should=~ /Standalone/
    end

    it 'should fall back to nil if Standalone framework not supported for zip file' do
      app = spec_asset("tests/standalone/java_app/target/zip/" +
        "standalone-java-app-1.0.0.BUILD-SNAPSHOT-jar.zip")
      framework(app).should == nil
    end

    it 'should fall back to Standalone app if dir does not match other frameworks' do
      app = spec_asset('tests/standalone/python_app')
      framework(app,false,[["standalone"]]).to_s.should=~ /Standalone/
    end

     it 'should detect default Java runtime with a zip of jars' do
        app = spec_asset("tests/standalone/java_app/target/zip/" +
          "standalone-java-app-1.0.0.BUILD-SNAPSHOT-jar.zip")
        framework(app,false,[["standalone"]]).default_runtime(app).should == "java"
      end

    it 'should fall back to nil if Standalone framework not supported for dir' do
      app = spec_asset('tests/standalone/python_app')
      framework(app).should == nil
    end

    it 'should detect default Java runtime with a single jar' do
      app = spec_asset("tests/standalone/java_app/target/" +
        "standalone-java-app-1.0.0.BUILD-SNAPSHOT.jar")
      framework(app,false,[["standalone"]]).default_runtime(app).should == "java"
    end

    it 'should detect default Java runtime with a zip of jars' do
      app = spec_asset("tests/standalone/java_app/target/zip/" +
        "standalone-java-app-1.0.0.BUILD-SNAPSHOT-jar.zip")
      framework(app,false,[["standalone"]]).default_runtime(app).should == "java"
    end

    it 'should detect default Java runtime with a dir containing zip of jar files' do
      app = spec_asset('tests/standalone/java_app/target/zip')
      framework(app,false,[["standalone"]]).default_runtime(app).should == "java"
    end

    it 'should detect default Java runtime with a dir containing jar files' do
      app = spec_asset('tests/standalone/java_app/target')
      framework(app,false,[["standalone"]]).default_runtime(app).should == "java"
    end

    it 'should detect default Java runtime with a single class' do
      app = spec_asset('tests/standalone/java_app/target/classes/HelloCloud.class')
      framework(app,false,[["standalone"]]).default_runtime(app).should == "java"
    end

    it 'should detect default Java runtime with a dir containing class files' do
      app = spec_asset('tests/standalone/java_app/target/classes')
      framework(app,false,[["standalone"]]).default_runtime(app).should == "java"
    end

    it 'should detect default Ruby runtime with a single rb file' do
      app = spec_asset('tests/standalone/ruby_app/main.rb')
      framework(app,false,[["standalone"]]).default_runtime(app).should == "ruby18"
    end

    it 'should detect default Ruby runtime with a dir containing rb files' do
      app = spec_asset('tests/standalone/simple_ruby_app')
      framework(app,false,[["standalone"]]).default_runtime(app).should == "ruby18"
    end

    it 'should return nil for default runtime if framework is not standalone' do
       app = spec_asset('tests/lift/hello_lift/target')
       framework(app,false,[["standalone"]]).default_runtime(app).should == nil
    end

    it 'should return nil for default runtime if zip does not contain jars' do
       app = spec_asset("tests/standalone/python_app/target/zip/" +
         "standalone-python-1.0.0.BUILD-SNAPSHOT-script.zip")
       framework(app,false,[["standalone"]]).default_runtime(app).should == nil
    end

    it 'should return nil for default runtime if dir contains zip with no jars' do
       app = spec_asset('tests/standalone/python_app/target/zip')
       framework(app,false,[["standalone"]]).default_runtime(app).should == nil
    end

    it 'should return nil for default runtime if file does not match any rules' do
       app = spec_asset('tests/standalone/python_app')
       framework(app,false,[["standalone"]]).default_runtime(app).should == nil
    end

    it 'should return expected default memory for standalone Java apps' do
      app = spec_asset('tests/standalone/java_app/target')
      framework(app,false,[["standalone"]]).memory("java").should == '512M'
    end

    it 'should return expected default memory for standalone Java 7 apps' do
      app = spec_asset('tests/standalone/java_app/target')
      framework(app,false,[["standalone"]]).memory("java7").should == '512M'
    end

    it 'should return expected default memory for standalone Ruby 1.8 apps' do
      app = spec_asset('tests/standalone/ruby_app/main.rb')
      framework(app,false,[["standalone"]]).memory("ruby18").should == '128M'
    end

    it 'should return expected default memory for standalone Ruby 1.9 apps' do
       app = spec_asset('tests/standalone/ruby_app/main.rb')
       framework(app,false,[["standalone"]]).memory("ruby19").should == '128M'
    end

    it 'should return expected default memory for standalone PHP apps' do
       app = spec_asset('tests/standalone/php_app')
       framework(app,false,[["standalone"]]).memory("php").should == '128M'
    end

    it 'should return expected default memory for standalone apps with other runtimes' do
       app = spec_asset('tests/standalone/python_app')
       framework(app,false,[["standalone"]]).memory("python").should == '64M'
    end

    it 'should return expected default memory for non-standalone apps' do
       app = spec_asset('tests/rails3/hello_vcap')
       framework(app).mem.should == '256M'
    end
  end

  def framework app, explode=false, available_frameworks=[]
    unless explode == true
      return VMC::Cli::Framework.detect(app, available_frameworks)
    end
    Dir.mktmpdir {|dir|
      exploded_dir = File.join(dir, "exploded")
      VMC::Cli::ZipUtil.unpack(app, exploded_dir)
      VMC::Cli::Framework.detect(exploded_dir, available_frameworks)
    }
  end

  def get_war_file app
    Dir.chdir(app)
    war_file = Dir.glob('*.war').first
  end
end
