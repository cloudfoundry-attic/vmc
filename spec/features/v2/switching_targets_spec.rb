require "spec_helper"

if ENV['VMC_V2_TEST_TARGET']
  describe 'A new user tries to use VMC against v2 production', :ruby19 => true do
    include ConsoleAppSpeckerMatchers

    let(:target) { ENV['VMC_V2_TEST_TARGET'] }

    before do
      Interact::Progress::Dots.start!
    end

    after do
      Interact::Progress::Dots.stop!
    end

    it "can switch targets, even if a target is invalid" do
      run("#{vmc_bin} target invalid-target") do |runner|
        expect(runner).to say "Target refused"
        runner.wait_for_exit
      end

      run("#{vmc_bin} target #{target}") do |runner|
        expect(runner).to say "Setting target"
        expect(runner).to say target
        runner.wait_for_exit
      end
    end
  end
else
  $stderr.puts 'Skipping v2 integration specs; please provide $VMC_V2_TEST_TARGET'
end
