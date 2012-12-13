require 'spec_helper'

if ENV['VMC_TEST_USER'] && ENV['VMC_TEST_PASSWORD'] && ENV['VMC_TEST_TARGET']
  describe 'A new user tries to use VMC against v1 production' do
    let(:target) { ENV['VMC_TEST_TARGET'] }
    let(:username) { ENV['VMC_TEST_USER'] }
    let(:password) { ENV['VMC_TEST_PASSWORD'] }
    let(:output) { StringIO.new }
    let(:out) { output.string.gsub(/\.  \x08([\x08\. ]+)/, "... ") } # trim animated dots

    let(:app) {
      fuzz =
        if defined? TRAVIS_BUILD_ID
          TRAVIS_BUILD_ID
        else
          Time.new.to_f.to_s.gsub(".", "_")
        end

      "hello-sinatra-#{fuzz}"
    }

    before do
      FileUtils.rm_rf VMC::CONFIG_DIR
      stub(VMC::CLI).exit { |code| code }
      WebMock.allow_net_connect!
    end

    after do
      with_output_to { VMC::CLI.start %W(delete #{app} -f) }
    end

    it 'and pushes a simple sinatra app using defaults as much as possible' do
      vmc_ok %W(target #{target}) do |out|
        expect(out).to eq <<-OUT.strip_heredoc
          Setting target to https://#{target}... OK
        OUT
      end

      vmc_ok %W(login #{username} --password #{password}) do |out|
        expect(out).to eq <<-OUT.strip_heredoc
          target: https://#{target}

          Authenticating... OK
        OUT
      end

      vmc_fail %W(app #{app}) do |out|
        expect(out).to eq <<-OUT.strip_heredoc
          Unknown app '#{app}'.
        OUT
      end

      Dir.chdir("#{SPEC_ROOT}/assets/hello-sinatra") do
        vmc_ok %W(push #{app} --runtime ruby19 --url #{app}-vmc-test.cloudfoundry.com -f) do |out|
          expect(out).to eq <<-OUT.strip_heredoc
            Creating #{app}... OK

            Updating #{app}... OK
            Uploading #{app}... OK
            Starting #{app}... OK
            Checking #{app}... OK
          OUT
        end

        vmc_ok %W(push #{app}) do |out|
          expect(out).to eq <<-OUT.strip_heredoc
            Uploading #{app}... OK
            Stopping #{app}... OK

            Starting #{app}... OK
            Checking #{app}... OK
          OUT
        end
      end

      vmc_ok %W(delete #{app} -f) do |out|
        expect(out).to eq <<-OUT.strip_heredoc
          Deleting #{app}... OK
        OUT
      end
    end
  end
else
  $stderr.puts 'Skipping integration specs; please provide $VMC_TEST_TARGET, $VMC_TEST_USER, and $VMC_TEST_PASSWORD'
end
