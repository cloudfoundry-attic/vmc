require "spec_helper"

if ENV['VMC_V2_TEST_USER'] && ENV['VMC_V2_TEST_PASSWORD'] && ENV['VMC_V2_TEST_TARGET'] && ENV['VMC_V2_OTHER_TEST_USER']
  describe 'A user logs in and switches spaces, after a different user has logged in', :ruby19 => true do
    include ConsoleAppSpeckerMatchers

    let(:target) { ENV['VMC_V2_TEST_TARGET'] }
    let(:username) { ENV['VMC_V2_TEST_USER'] }
    let(:password) { ENV['VMC_V2_TEST_PASSWORD'] }

    let(:second_username) { ENV['VMC_V2_OTHER_TEST_USER'] }
    let(:second_organization) { ENV['VMC_V2_OTHER_TEST_ORGANIZATION'] }
    let(:second_space) { ENV['VMC_V2_OTHER_TEST_SPACE'] }
    let(:second_password) { ENV['VMC_V2_OTHER_TEST_PASSWORD'] || ENV['VMC_V2_TEST_PASSWORD'] }

    before do
      Interact::Progress::Dots.start!

      run("#{vmc_bin} target #{target}") do |runner|
        expect(runner).to say "Setting target"
        expect(runner).to say target
        runner.wait_for_exit
      end

      run("#{vmc_bin} logout") do |runner|
        runner.wait_for_exit
      end
    end

    after do
      Interact::Progress::Dots.stop!
    end

    context "when a different user is already logged in" do
      before do
        run("#{vmc_bin} login #{username} --password #{password}") do |runner|
          expect(runner).to say "Authenticating... OK"

          expect(runner).to say "Switching to organization"
          expect(runner).to say "OK"

          expect(runner).to say "Space"
          runner.send_keys("1")

          expect(runner).to say "Switching to space"
          expect(runner).to say "OK"

          runner.wait_for_exit
        end
      end

      it "can switch spaces on login" do
        run("#{vmc_bin} login #{second_username} --password #{second_password} --organization #{second_organization} --space #{second_space}") do |runner|
          expect(runner).to say "Authenticating... OK"
          expect(runner).to say "Switching to organization #{second_organization}... OK"
          expect(runner).to say "Switching to space #{second_space}... OK"
          runner.wait_for_exit
        end
      end
    end
  end
else
  $stderr.puts 'Skipping v2 integration specs; please provide $VMC_V2_TEST_TARGET, $VMC_V2_TEST_USER, $VMC_V2_TEST_PASSWORD, and $VMC_V2_OTHER_TEST_USER'
end
