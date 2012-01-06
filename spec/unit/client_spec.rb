require 'spec_helper'

describe 'VMC::Client' do
  include WebMock::API

  before(:all) do
    @target = VMC::DEFAULT_TARGET
    @local_target = VMC::DEFAULT_LOCAL_TARGET
    @user = 'derek@gmail.com'
    @password = 'foo'
    @auth_token = spec_asset('sample_token.txt')
  end

  before(:each) do
    # make sure these get cleared so we don't have tests pass that shouldn't
    RestClient.proxy = nil
    ENV['http_proxy'] = nil
    ENV['https_proxy'] = nil
  end

  it 'should report its version' do
    VMC::Client.version.should =~ /\d.\d.\d/
  end

  it 'should default to local target' do
    client = VMC::Client.new
    client.target.should == VMC::DEFAULT_TARGET
  end

  it 'should default to use secure protocol' do
    client = VMC::Client.new
    client.target.match(/^https/)
  end

  it 'should normalize target with no scheme' do
    client = VMC::Client.new('api.cloudfoundry.com')
    client.target.should == 'http://api.cloudfoundry.com'
  end

  it 'should properly initialize with auth_token' do
    client = VMC::Client.new(@target, @auth_token)
    client.target.should     == @target
    client.auth_token.should == @auth_token
  end

  it 'should allow login correctly and return an auth_token' do
    login_path = "#{@local_target}/users/#{@user}/tokens"
    stub_request(:post, login_path).to_return(File.new(spec_asset('login_success.txt')))
    client = VMC::Client.new(@local_target)
    auth_token = client.login(@user, @password)
    client.target.should == @local_target
    client.user.should == @user
    client.auth_token.should be
    auth_token.should be
    auth_token.should == client.auth_token
  end

  it 'should raise exception if login fails' do
    login_path = "#{@local_target}/users/#{@user}/tokens"
    stub_request(:post, login_path).to_return(File.new(spec_asset('login_fail.txt')))
    client = VMC::Client.new(@local_target)
    expect { client.login(@user, @password) }.to raise_error(VMC::Client::TargetError)
  end

  it 'should allow admin users to proxy for others' do
    proxy = 'vadim@gmail.com'
    client = VMC::Client.new(@target)
    client.proxy_for(proxy)
    client.proxy.should == proxy
  end

  it 'should properly get info for valid target cloud' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_return.txt')))
    client = VMC::Client.new(@local_target)
    info = client.info
    a_request(:get, info_path).should have_been_made.once
    info.should have_key :support
    info.should have_key :description
    info.should have_key :name
    info.should have_key :version
    info.should have_key :build
  end

  it 'should raise and exception for a bad target' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_return_bad.txt')))
    client = VMC::Client.new(@local_target)
    expect {info = client.info}.to raise_error(VMC::Client::BadResponse)
    a_request(:get, info_path).should have_been_made.once
  end

  it 'should have target_valid? return true for a good target' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_return.txt')))
    client = VMC::Client.new(@local_target)
    client.target_valid?.should be_true
  end

  it 'should have target_valid? return false for a bad target' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_return_bad.txt')))
    client = VMC::Client.new(@local_target)
    client.target_valid?.should be_false
  end

  it 'should respond ok if properly logged in' do
    login_path = "#{@local_target}/users/#{@user}/tokens"
    stub_request(:post, login_path).to_return(File.new(spec_asset('login_success.txt')))
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    client = VMC::Client.new(@local_target)
    client.login(@user, @password)
    client.logged_in?.should be_true
  end

  it 'should fail when trying to change password unless logged in' do
    login_path = "#{@local_target}/users/#{@user}/tokens"
    stub_request(:post, login_path).to_return(File.new(spec_asset('login_success.txt')))
    user_info_path = "#{@local_target}/users/#{@user}"
    stub_request(:get, user_info_path).to_return(File.new(spec_asset('user_info.txt')))
    stub_request(:put, user_info_path)
    client = VMC::Client.new(@local_target)
    client.login(@user, @password)
    client.change_password('bar')
  end

  it 'should get a proper list of apps' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    apps_path = "#{@local_target}/#{VMC::APPS_PATH}"
    stub_request(:get, apps_path).to_return(File.new(spec_asset('app_listings.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    apps = client.apps
    apps.should have(1).items
    app = apps.first
    app.should have_key :state
    app.should have_key :uris
    app.should have_key :name
    app.should have_key :services
    app.should have_key :instances
  end

  it 'should get a proper list of users' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    users_path = "#{@local_target}/#{VMC::USERS_PATH}"
    stub_request(:get, users_path).to_return(File.new(spec_asset('list_users.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    users = client.users
    users.should have(4).items
    user = users.first
    user.should have_key :email
    user.should have_key :admin
    user.should have_key :apps
  end

  it 'should get a proper list of services' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    services_path = "#{@local_target}/#{VMC::Client.path(VMC::GLOBAL_SERVICES_PATH)}"
    stub_request(:get, services_path).to_return(File.new(spec_asset('global_service_listings.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    services = client.services_info
    services.should have(2).items
    # FIXME, add in more details.
  end

  it 'should get a proper list of provisioned services' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    services_path = "#{@local_target}/#{VMC::SERVICES_PATH}"
    stub_request(:get, services_path).to_return(File.new(spec_asset('service_listings.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    app_services = client.services
    app_services.should have(1).items
    redis = app_services.first
    redis.should have_key :type
    redis.should have_key :vendor
  end

  it 'should raise when trying to create an app with no manifest' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    app_path = "#{@local_target}/#{VMC::APPS_PATH}"
    stub_request(:post, app_path).to_return(File.new(spec_asset('bad_create_app.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    expect { client.create_app('foo') }.to  raise_error(VMC::Client::NotFound)
  end

  it 'should create an app with a simple manifest' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    app_path = "#{@local_target}/#{VMC::APPS_PATH}"
    stub_request(:post, app_path).to_return(File.new(spec_asset('good_create_app.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    manifest = {
      :name => 'foo',
      :uris => ['foo.vcap.me'],
      :instances => 1,
      :staging => { :model => 'nodejs/1.0' },
      :resources => { :memory => 64 }
    }
    client.create_app('foo', manifest)
  end

  it 'should allow us to delete an app we created' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    app_path = "#{@local_target}/#{VMC::APPS_PATH}/foo"
    stub_request(:delete, app_path).to_return(File.new(spec_asset('delete_app.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    client.delete_app('foo')
  end

  it 'should provision a service' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    global_services_path = "#{@local_target}/#{VMC::Client.path(VMC::GLOBAL_SERVICES_PATH)}"
    stub_request(:get, global_services_path).to_return(File.new(spec_asset('global_service_listings.txt')))
    services_path = "#{@local_target}/#{VMC::SERVICES_PATH}"
    stub_request(:post, services_path).to_return(File.new(spec_asset('good_create_service.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    client.create_service('redis', 'foo')
  end

  it 'should complain if we try to provision a service that already exists with same name' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    global_services_path = "#{@local_target}/#{VMC::Client.path(VMC::GLOBAL_SERVICES_PATH)}"
    stub_request(:get, global_services_path).to_return(File.new(spec_asset('global_service_listings.txt')))
    services_path = "#{@local_target}/#{VMC::SERVICES_PATH}"
    stub_request(:post, services_path).to_return(File.new(spec_asset('service_already_exists.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    expect { client.create_service('redis', 'foo') }.to raise_error(VMC::Client::NotFound)
  end

  it 'should complain if we try to provision a service that does not exist' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    global_services_path = "#{@local_target}/#{VMC::Client.path(VMC::GLOBAL_SERVICES_PATH)}"
    stub_request(:get, global_services_path).to_return(File.new(spec_asset('global_service_listings.txt')))
    services_path = "#{@local_target}/#{VMC::SERVICES_PATH}"
    stub_request(:post, services_path).to_return(File.new(spec_asset('service_not_found.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    expect { client.create_service('redis', 'foo') }.to raise_error(VMC::Client::NotFound)
  end

  it 'should allow us to delete a provisioned service' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    services_path = "#{@local_target}/#{VMC::SERVICES_PATH}"
    stub_request(:get, services_path).to_return(File.new(spec_asset('service_listings.txt')))
    services_path = "#{@local_target}/#{VMC::SERVICES_PATH}/redis-7ed7da9"
    stub_request(:delete, services_path)
    client = VMC::Client.new(@local_target, @auth_token)
    client.delete_service('redis-7ed7da9')
  end

  it 'should bind a service to an app' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    app_path = "#{@local_target}/#{VMC::APPS_PATH}/foo"
    stub_request(:get, app_path).to_return(File.new(spec_asset('app_info.txt')))
    stub_request(:put, app_path)
    client = VMC::Client.new(@local_target, @auth_token)
    client.bind_service('my-redis', 'foo')
    a_request(:get, app_path).should have_been_made.once
    a_request(:put, app_path).should have_been_made.once
  end

  it 'should unbind an existing service from an app' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    app_path = "#{@local_target}/#{VMC::APPS_PATH}/foo"
    stub_request(:get, app_path).to_return(File.new(spec_asset('app_info.txt')))
    stub_request(:put, app_path)
    client = VMC::Client.new(@local_target, @auth_token)
    client.unbind_service('my-redis', 'foo')
    a_request(:get, app_path).should have_been_made.once
    a_request(:put, app_path).should have_been_made.once
  end

  it 'should set a proxy if one is set' do
    target = "http://nonlocal.domain.com"
    info_path = "#{target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_return.txt')))
    proxy = 'http://proxy.vmware.com:3128'
    ENV['http_proxy'] = proxy
    client = VMC::Client.new(target)
    info = client.info
    RestClient.proxy.should == proxy
  end

  it 'should not set a proxy when accessing localhost' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_return.txt')))
    proxy = 'http://proxy.vmware.com:3128'
    ENV['http_proxy'] = proxy
    client = VMC::Client.new(@local_target)
    info = client.info
    RestClient.proxy.should == nil
  end

  it 'should use a secure proxy over a normal proxy if one is set' do
    info_path = "#{@target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_return.txt')))
    proxy = 'http://proxy.vmware.com:3128'
    secure_proxy = 'http://secure-proxy.vmware.com:3128'
    ENV['http_proxy'] = proxy
    ENV['https_proxy'] = secure_proxy
    client = VMC::Client.new(@target)
    info = client.info
    RestClient.proxy.should == secure_proxy
  end

  it 'should not use a secure proxy for non-secure site' do
    target = "http://nonlocal.domain.com"
    info_path = "#{target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_return.txt')))
    proxy = 'http://proxy.vmware.com:3128'
    secure_proxy = 'http://secure-proxy.vmware.com:3128'
    ENV['http_proxy'] = proxy
    ENV['https_proxy'] = secure_proxy
    client = VMC::Client.new(target)
    info = client.info
    RestClient.proxy.should == proxy
  end

  it 'should fail when there is a service gateway failure' do
    info_path = "#{@local_target}/#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))
    global_services_path = "#{@local_target}/#{VMC::Client.path(VMC::GLOBAL_SERVICES_PATH)}"
    stub_request(:get, global_services_path).to_return(File.new(spec_asset('global_service_listings.txt')))
    services_path = "#{@local_target}/#{VMC::SERVICES_PATH}"
    # A service gateway failure will typically happen when provisioning a new service instance -
    # e.g. provisioning too many instances of mysql service.
    stub_request(:post, services_path).to_return(File.new(spec_asset('service_gateway_fail.txt')))
    client = VMC::Client.new(@local_target, @auth_token)
    expect { client.create_service('mysql', 'foo') }.to raise_error(VMC::Client::TargetError)
  end

  # WebMock.allow_net_connect!

end
