require 'spec_helper'

describe 'VMC::Cli::Command::Apps' do

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

  it 'should fail when there is an attempt to upload an app with links reaching outside the app root' do
    @client = VMC::Client.new(@local_target, @auth_token)

    login_path = "#{@local_target}/users/#{@user}/tokens"
    stub_request(:post, login_path).to_return(File.new(spec_asset('login_success.txt')))
    info_path = "#{@local_target}#{VMC::INFO_PATH}"
    stub_request(:get, info_path).to_return(File.new(spec_asset('info_authenticated.txt')))

    app = spec_asset('tests/node/app_with_external_link')
    options = {
        :name => 'foo',
        :uris => ['foo.vcap.me'],
        :instances => 1,
        :staging => { :model => 'nodejs/1.0' },
        :path => app,
        :resources => { :memory => 64 }
    }
    command = VMC::Cli::Command::Apps.new(options)
    command.client(@client)

    app_path = "#{@local_target}#{VMC::APPS_PATH}/foo"
    stub_request(:get, app_path).to_return(File.new(spec_asset('app_info.txt')))

    # We are using the 'update' command to save on all of the mocking set up that is needed
    # when using 'push' - we can do this because the upload logic is shared by 'push' & 'update''
    expect { command.update('foo')}.to raise_error(/Can't deploy application containing links/)
  end

end
