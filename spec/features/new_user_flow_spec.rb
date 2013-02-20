require 'spec_helper'
require "webmock/rspec"

INTEGRATE_WITH = ENV["INTEGRATE_WITH"] || "default"

if ENV['VMC_TEST_USER'] && ENV['VMC_TEST_PASSWORD'] && ENV['VMC_TEST_TARGET']
  describe 'A new user tries to use VMC against v1 production', :ruby19 => true do
    include ConsoleAppSpeckerMatchers
    include VMC::Interactive

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
      FileUtils.rm_rf File.expand_path(VMC::CONFIG_DIR)
      WebMock.allow_net_connect!
      Interact::Progress::Dots.start!
    end

    after do
      vmc %W(delete #{app} -f --no-script)
      Interact::Progress::Dots.stop!
    end

    let(:vmc_bin) do
      vmc = File.expand_path("#{SPEC_ROOT}/../bin/vmc.dev")
      if INTEGRATE_WITH != 'default'
        "rvm #{INTEGRATE_WITH}@vmc do #{vmc}"
      else
        vmc
      end
    end

    it 'pushes a simple sinatra app using defaults as much as possible' do
      run("#{vmc_bin} target http://#{target}") do |runner|
        expect(runner).to say %r{Setting target to http://#{target}... OK}
      end

      run("#{vmc_bin} login") do |runner|
        expect(runner).to say %r{target: https?://#{target}}

        expect(runner).to say "Email>"
        runner.send_keys username

        expect(runner).to say "Password>"
        runner.send_keys password

        expect(runner).to say "Authenticating... OK"
      end

      run("#{vmc_bin} app #{app}") do |runner|
        expect(runner).to say "Unknown app '#{app}'."
      end

      Dir.chdir("#{SPEC_ROOT}/assets/hello-sinatra") do
        run("#{vmc_bin} push") do |runner|
          expect(runner).to say "Name>"
          runner.send_keys app

          expect(runner).to say "Instances> 1"
          runner.send_keys ""

          expect(runner).to say "1: sinatra"
          expect(runner).to say "2: other"
          expect(runner).to say "Framework> sinatra"
          runner.send_keys ""

          expect(runner).to say "1: ruby"
          expect(runner).to say "Runtime>"
          runner.send_keys "ruby19"

          expect(runner).to say "1:"
          expect(runner).to say "Memory Limit>"
          runner.send_keys "64M"

          expect(runner).to say "Creating #{app}... OK"

          expect(runner).to say "1: #{app}."
          expect(runner).to say "2: none"
          expect(runner).to say "Domain>"
          runner.send_keys ""

          expect(runner).to say "Updating #{app}... OK"

          expect(runner).to say "Create services for application?> n"
          runner.send_keys ""

          expect(runner).to say "Save configuration?> n"
          runner.send_keys ""

          expect(runner).to say "Uploading #{app}... OK"
          expect(runner).to say "Starting #{app}... OK"
          expect(runner).to say "Checking #{app}... OK", 30
        end
      end

      run("#{vmc_bin} delete #{app}") do |runner|
        expect(runner).to say "Really delete #{app}?>"
        runner.send_keys "y"

        expect(runner).to say "Deleting #{app}... OK"
      end
    end
  end
else
  $stderr.puts 'Skipping integration specs; please provide $VMC_TEST_TARGET, $VMC_TEST_USER, and $VMC_TEST_PASSWORD'
end
