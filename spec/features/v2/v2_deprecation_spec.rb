require "spec_helper"

if ENV['VMC_V2_TEST_TARGET']
  describe 'v2 deprecation', :ruby19 => true do
    include ConsoleAppSpeckerMatchers

    let(:target) { ENV['VMC_V2_TEST_TARGET'] }

    before do
      Interact::Progress::Dots.start!
    end

    after do
      Interact::Progress::Dots.stop!
    end

    it "targeting a v2 instance informs the user to use CF to target v2 instances" do
      run("#{vmc_bin} target #{target}") do |runner|
        expect(runner).to say "Setting target"
        expect(runner).to say target
        expect(runner).to say "Warning: Targeting a v2 instance. Further commands will fail until a v1 instance is targeted. Please use the 'cf' command to target v2 instances."
        runner.wait_for_exit
      end
    end

    it "running any command against a targeted v2 instance produces an error" do
      run("#{vmc_bin} target #{target}") { |runner| runner.wait_for_exit }

      error_message = "You are targeting a version 2 instance of Cloud Foundry: you must use the 'cf' command line client (which you can get with 'gem install cf')."

      run("#{vmc_bin} push") do |runner|
        expect(runner).to say error_message
        runner.wait_for_exit
      end

      run("#{vmc_bin} create-service") do |runner|
        expect(runner).to say error_message
        runner.wait_for_exit
      end

      run("#{vmc_bin} start") do |runner|
        expect(runner).to say error_message
        runner.wait_for_exit
      end

      run("#{vmc_bin} login") do |runner|
        expect(runner).to say error_message
        runner.wait_for_exit
      end
    end

  end

else
  $stderr.puts 'Skipping v2 integration specs; please provide $VMC_V2_TEST_TARGET'
end
