require 'spec_helper'
require "webmock/rspec"

if ENV['VMC_TEST_USER'] && ENV['VMC_TEST_PASSWORD'] && ENV['VMC_TEST_TARGET']
  describe 'A new user tries to use VMC against v1 production' do
    let(:target) { ENV['VMC_TEST_TARGET'] }
    let(:username) { ENV['VMC_TEST_USER'] }
    let(:password) { ENV['VMC_TEST_PASSWORD'] }
    let(:output) { StringIO.new }
    let(:out) { output.string.strip_progress_dots }

    let(:app) do
      fuzz = defined?(TRAVIS_BUILD_ID) ? TRAVIS_BUILD_ID : Time.new.to_f.to_s.gsub(".", "_")
      "hello-sinatra-#{fuzz}"
    end

    before do
      FileUtils.rm_rf VMC::CONFIG_DIR
      WebMock.allow_net_connect!
    end

    after { vmc %W(delete #{app} -f --no-script) }

    it 'and pushes a simple sinatra app using defaults as much as possible' do
      vmc %W[target #{target} --no-script]
      expect_success
      expect(stdout.string.strip_progress_dots).to eq <<-OUT.strip_heredoc
        Setting target to https://#{target}... OK
      OUT

      vmc %W[login #{username} --password #{password} --no-script]
      expect_success
      expect(stdout.string.strip_progress_dots).to eq <<-OUT.strip_heredoc
        target: https://#{target}

        Authenticating... OK
      OUT

      vmc %W[app #{app} --no-script]
      expect_failure
      expect(stderr.string).to eq <<-OUT.strip_heredoc
        Unknown app '#{app}'.
      OUT

      Dir.chdir("#{SPEC_ROOT}/assets/hello-sinatra") do
        vmc %W[push #{app} --runtime ruby19 --url #{app}-vmc-test.cloudfoundry.com -f --no-script]
        expect_success
        expect(stdout.string.strip_progress_dots).to eq <<-OUT.strip_heredoc
          Creating #{app}... OK

          Updating #{app}... OK
          Uploading #{app}... OK
          Starting #{app}... OK
          Checking #{app}... OK
        OUT

        vmc %W[push #{app} --no-script]
        expect_success
        expect(stdout.string.strip_progress_dots).to eq <<-OUT.strip_heredoc
          Uploading #{app}... OK
          Stopping #{app}... OK

          Starting #{app}... OK
          Checking #{app}... OK
        OUT
      end

      vmc %W[delete #{app} -f --no-script]
      expect_success
      expect(stdout.string.strip_progress_dots).to eq <<-OUT.strip_heredoc
        Deleting #{app}... OK
      OUT
    end
  end
else
  $stderr.puts 'Skipping integration specs; please provide $VMC_TEST_TARGET, $VMC_TEST_USER, and $VMC_TEST_PASSWORD'
end
