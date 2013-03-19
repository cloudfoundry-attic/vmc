require 'spec_helper'

describe VMC::CLI do
  let(:context) { VMC::CLI.new }
  let(:command) { nil }

  let(:fake_home_dir) { nil }
  stub_home_dir_with { fake_home_dir }

  describe "#wrap_errors" do
    let(:inputs) { {} }

    subject do
      capture_output do
        stub(context).input { inputs }
        context.wrap_errors { action.call }
      end
    end

    context "with a CFoundry::Timeout" do
      let(:action) { proc { raise CFoundry::Timeout.new(123, "fizzbuzz") } }

      it_behaves_like "an error that's obvious to the user",
        :with_message => "fizzbuzz"
    end

    context "with a UserError" do
      let(:action) { proc { context.fail "foo bar" } }

      it_behaves_like "an error that's obvious to the user",
        :with_message => "foo bar"

      it "saves it in the crashlog" do
        mock(context).log_error(anything)
        subject
      end
    end

    context "with a UserFriendlyError" do
      let(:action) { proc { raise VMC::UserFriendlyError.new("user friendly") } }

      it_behaves_like "an error that's obvious to the user",
        :with_message => "user friendly"
    end

    context "with a SystemExit" do
      let(:action) { proc { exit 1 } }

      it_behaves_like "an error that gets passed through",
        :with_exception => SystemExit
    end

    context "with a Mothership::Error" do
      let(:action) { proc { raise Mothership::Error } }

      it_behaves_like "an error that gets passed through",
        :with_exception => Mothership::Error
    end

    context "with an Interrupt" do
      let(:action) { proc { raise Interrupt } }

      it "sets the exit code to 130" do
        mock(context).exit_status(130)
        subject
      end
    end

    context "with a CFoundry authentication error" do
      let(:action) { proc { raise CFoundry::InvalidAuthToken.new("foo bar") } }
      let(:asked) { false }

      before do
        $vmc_asked_auth = asked
      end

      it "tells the user they are not authenticated" do
        stub(context).invoke(:login)
        subject
        expect(stdout.string).to include "Not authenticated! Try logging in:"
      end

      it "asks the user to log in" do
        mock(context).invoke(:login)
        subject
      end

      context "and after logging in they got another authentication error" do
        let(:asked) { true }

        it "does not ask them to log in" do
          dont_allow(context).invoke(:login)
          subject
        end

        it_behaves_like "an error that's obvious to the user",
          :with_message => "Denied: foo bar"
      end
    end

    context "with an arbitrary exception" do
      let(:action) { proc { raise "foo bar" } }

      it "logs the error" do
        mock(context).log_error(anything)
        subject
      end

      it "prints the message" do
        subject
        expect(stderr.string).to include "RuntimeError: foo bar"
      end

      it "sets the exit code to 1" do
        mock(context).exit_status(1)
        subject
      end

      it "tells the user to check ~/.vmc/crash" do
        subject
        expect(stderr.string).to include VMC::CRASH_FILE
      end

      context "when we are debugging" do
        let(:inputs) { { :debug => true } }

        it_behaves_like "an error that gets passed through",
          :with_exception => RuntimeError
      end
    end
  end

  describe '#execute' do
    let(:inputs) { {} }
    let(:client) { fake_client }

    before do
      any_instance_of(VMC::CLI) do |cli|
        stub(cli).client { client }
      end
    end

    subject do
      capture_output do
        stub(context).input { inputs }
        context.execute(command, [])
      end
    end

    describe "token refreshing" do
      let(:context) { TokenRefreshDummy.new }
      let(:command) { Mothership.commands[:refresh_token] }
      let(:auth_token) { CFoundry::AuthToken.new("old-header") }
      let(:new_auth_token) { CFoundry::AuthToken.new("new-header") }

      class TokenRefreshDummy < VMC::CLI
        class << self
          attr_accessor :new_token
        end

        def precondition; end

        desc "XXX"
        def refresh_token
          if client
            client.token = self.class.new_token
          end
        end
      end

      context "when there is a target" do
        before do
          TokenRefreshDummy.new_token = nil
          client.token = auth_token
        end

        context "when the token refreshes" do
          it "saves to the target file" do
            any_instance_of(TokenRefreshDummy) do |trd|
              trd.new_token = new_auth_token

              stub(trd).target_info { {} }
              mock(trd).save_target_info(anything) do |info|
                expect(info[:token]).to eq new_auth_token.auth_header
              end
            end

            subject
          end
        end

        context "but there is no token initially" do
          let(:auth_token) { nil }

          it "doesn't save the new token because something else probably did" do
            dont_allow(context).save_target_info(anything)
            subject
          end
        end

        context "and the token becomes nil" do
          let(:new_auth_token) { nil }

          it "doesn't save the nil token" do
            dont_allow(context).save_target_info(anything)
            subject
          end
        end
      end

      context "when there is no target" do
        let(:client) { nil }

        it "doesn't try to compare the tokens" do
          expect { subject }.to_not raise_error
        end
      end
    end
  end

  describe '#log_error' do
    subject do
      context.log_error(exception)
      File.read(File.expand_path(VMC::CRASH_FILE))
    end

    context 'when the exception is a normal error' do
      let(:exception) do
        error = StandardError.new("gemfiles are kinda hard")
        error.set_backtrace(["fo/gems/bar", "baz quick"])
        error
      end

      it { should include "Time of crash:"}
      it { should include "gemfiles are kinda hard" }
      it { should include "bar" }
      it { should_not include "fo/gems/bar" }
      it { should include "baz quick" }
    end

    context 'when the exception is an APIError' do
      let(:request) { { :method => "GET", :url => "http://api.cloudfoundry.com/foo", :headers => {}, :body => nil } }
      let(:response) { { :status => 404, :body => "bar", :headers => {} } }
      let(:exception) do
        error = CFoundry::APIError.new(nil, nil, request, response)
        error.set_backtrace(["fo/gems/bar", "baz quick"])
        error
      end

      before do
        stub(response).body {"Response Body"}
      end

      it { should include "REQUEST: " }
      it { should include "RESPONSE: " }
    end
  end

  describe "#client_target" do
    subject { context.client_target }

    context "when a ~/.vmc/target exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/new" }

      it "returns the target in that file" do
        expect(subject).to eq "https://api.some-domain.com"
      end
    end

    context "when a ~/.vmc_target exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/old" }

      it "returns the target in that file" do
        expect(subject).to eq "https://api.some-domain.com"
      end
    end

    context "when no target file exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/no_config" }

      it "returns nil" do
        expect(subject).to eq nil
      end
    end
  end

  describe "#targets_info" do
    subject { context.targets_info }

    context "when a ~/.vmc/tokens.yml exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/new" }

      it "returns the file's contents as a hash" do
        expect(subject).to eq({
          "https://api.some-domain.com" => {
            :token => "bearer some-token",
            :version => 2
          }
        })
      end
    end

    context "when a ~/.vmc_token file exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/old" }

      it "returns the target in that file" do
        expect(subject).to eq({
          "https://api.some-domain.com" => {
            :token => "bearer some-token"
          }
        })
      end
    end

    context "when no token file exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/no_config" }

      it "returns an empty hash" do
        expect(subject).to eq({})
      end
    end
  end

  describe "#target_info" do
    subject { VMC::CLI.new.target_info("https://api.some-domain.com") }

    context "when a ~/.vmc/tokens.yml exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/new" }

      it "returns the info for the given url" do
        expect(subject).to eq({
          :token => "bearer some-token",
          :version => 2
        })
      end
    end

    context "when a ~/.vmc_token file exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/old" }

      it "returns the info for the given url" do
        expect(subject).to eq({
          :token => "bearer some-token"
        })
      end
    end

    context "when no token file exists" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/no_config" }

      it "returns an empty hash" do
        expect(subject).to eq({})
      end
    end
  end

  describe "methods that update the token info" do
    before do
      stub(context).targets_info do
        {
          "https://api.some-domain.com" => { :token => "bearer token1" },
          "https://api.some-other-domain.com" => { :token => "bearer token2" }
        }
      end
    end

    describe "#save_target_info" do
      it "adds the given target info, and writes the result to ~/.vmc/tokens.yml" do
        context.save_target_info({ :token => "bearer token3" }, "https://api.some-domain.com")
        YAML.load_file(File.expand_path("~/.vmc/tokens.yml")).should == {
          "https://api.some-domain.com" => { :token => "bearer token3" },
          "https://api.some-other-domain.com" => { :token => "bearer token2" }
        }
      end
    end

    describe "#remove_target_info" do
      it "removes the given target, and writes the result to ~/.vmc/tokens.yml" do
        context.remove_target_info("https://api.some-domain.com")
        YAML.load_file(File.expand_path("~/.vmc/tokens.yml")).should == {
          "https://api.some-other-domain.com" => { :token => "bearer token2" }
        }
      end
    end
  end

  describe "#client" do
    let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/new" }

    before { stub(context).input { {} } }

    describe "the client's token" do
      it "constructs an AuthToken object with the data from the tokens.yml file" do
        expect(context.client.token).to be_a(CFoundry::AuthToken)
        expect(context.client.token.auth_header).to eq("bearer some-token")
      end

      it "does not assign an AuthToken on the client if there is no token stored" do
        mock(context).target_info("some-fake-target") { { :version => 2 } }
        expect(context.client("some-fake-target").token).to be_nil
      end
    end

    describe "the client's version" do
      it "uses the version stored in the yml file" do
        expect(context.client.version).to eq(2)
      end
    end

    context "when there is no target" do
      let(:fake_home_dir) { "#{SPEC_ROOT}/fixtures/fake_home_dirs/no_config" }

      it "returns nil" do
        expect(context.client).to eq(nil)
      end
    end

    context "with a v1 cloud controller" do
      before do
        stub(context).target_info { { :version => 1} }
      end

      it "connects using the v1 api" do
        expect(context.client).to be_a(CFoundry::V1::Client)
      end

      context "with a proxy user" do
        before { stub(context).input { {:proxy => 'foo@example.com'} } }

        it "uses the provided client proxy user" do
          expect(context.client.proxy).to eq('foo@example.com')
        end
      end

      context "when ENV['http_proxy'] is set" do
        before { ENV['http_proxy'] = "http://lower.example.com:80" }
        after { ENV.delete('http_proxy') }

        it "uses the http proxy URI on the enviroenment" do
          expect(context.client.http_proxy).to eq('http://lower.example.com:80')
        end
      end

      context "when ENV['HTTP_PROXY'] is set" do
        before { ENV['HTTP_PROXY'] = "http://upper.example.com:80" }
        after { ENV.delete('HTTP_PROXY') }

        it "uses the http proxy URI on the environement" do
          expect(context.client.http_proxy).to eq('http://upper.example.com:80')
        end
      end

      context "with a http proxy URI" do
        before do
          ENV['HTTP_PROXY'] = "http://should.be.overwritten.example.com:80"
          stub(context).input { {:http_proxy => 'http://arg.example.com:80'} }
        end
        after { ENV.delete('HTTP_PROXY') }

        it "uses the provided http proxy URI" do
          expect(context.client.http_proxy).to eq('http://arg.example.com:80')
        end
      end

    end

    context "with a v2 cloud controller" do
      before do
        stub(context).target_info { { :version => 2} }
      end

      it "connects using the v2 api" do
        expect(context.client).to be_a(CFoundry::V2::Client)
      end

      context "with a proxy user" do
        before { stub(context).input { {:proxy => 'foo@example.com'} } }

        it "foo" do
          expect {context.client}.to raise_error(VMC::UserError, "User switching not implemented for v2.")
        end
      end
    end
  end
end

