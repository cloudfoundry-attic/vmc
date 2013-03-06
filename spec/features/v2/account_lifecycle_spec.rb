require "spec_helper"
require "webmock/rspec"
require "ffaker"

if ENV['VMC_V2_TEST_USER'] && ENV['VMC_V2_TEST_PASSWORD'] && ENV['VMC_V2_TEST_TARGET']
  describe 'A new user tries to use VMC against v2 production', :ruby19 => true do
    before(:all) do
      WebMock.allow_net_connect!
    end

    after(:all) do
      WebMock.disable_net_connect!
    end

    let(:target) { ENV['VMC_V2_TEST_TARGET'] }
    let(:username) { ENV['VMC_V2_TEST_USER'] }
    let(:password) { ENV['VMC_V2_TEST_PASSWORD'] }

    let(:client) do
      client = CFoundry::V2::Client.new("https://#{target}")
      client.login(username, password)
      client
    end

    before do
      Interact::Progress::Dots.start!
    end

    after do
      Interact::Progress::Dots.stop!
    end

    it "registers a new account and deletes it" do
      pending "until we get some v2 admin credentials somewhere to actually run this with" if TRAVIS_BUILD_ID

      email = Faker::Internet.email
      run("#{vmc_bin} target #{target}") do |runner|
        runner.wait_for_exit
      end

      run("#{vmc_bin} login #{username} --password #{password}") do |runner|
        expect(runner).to say "Organization>"
        runner.send_keys "1"
        expect(runner).to say "Space>"
        runner.send_keys "1"
      end

      puts "registering #{email}"
      run("#{vmc_bin} register #{email} --password p") do |runner|
        expect(runner).to say "Confirm Password>"
        runner.send_keys 'p'
        expect(runner).to say "Your password strength is: good"
        expect(runner).to say "Creating user... OK"
        expect(runner).to say "Authenticating... OK"
      end

      run("#{vmc_bin} logout") do |runner|
        runner.wait_for_exit
      end

      run("#{vmc_bin} login #{username} --password #{password}") do |runner|
        expect(runner).to say "Organization>"
        runner.send_keys "1"
        expect(runner).to say "Space>"
        runner.send_keys "1"
      end

      # run("#{vmc_bin} delete-user #{email}") do |runner|
        # expect(runner).to say "Really delete user #{email}?>"
        # runner.send_keys "y"
        # expect(runner).to say "Deleting #{email}... OK"
      # end

      puts "deleting #{email}"
      client.login(email, "p")
      user = client.current_user
      guid = user.guid
      client.login(username, password)
      user.delete!
      client.base.uaa.delete_user(guid)
    end
  end
else
  $stderr.puts 'Skipping v2 integration specs; please provide $VMC_V2_TEST_TARGET, $VMC_V2_TEST_USER, and $VMC_V2_TEST_PASSWORD'
end
