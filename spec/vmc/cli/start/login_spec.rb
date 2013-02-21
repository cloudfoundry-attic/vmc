require 'spec_helper'

describe VMC::Start::Login do
  let(:client) { fake_client :organizations => [] }

  before do
    any_instance_of described_class do |cli|
      stub(cli).client { client }
    end

    described_class.class_eval do
      def wrap_errors
        yield
      end
    end
  end

  after do
    described_class.class_eval do
      remove_method :wrap_errors
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:login] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Authenticate with the target" }
      specify { expect(Mothership::Help.group(:start)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'flags' do
      subject { command.flags }

      its(["-o"]) { should eq :organization }
      its(["--org"]) { should eq :organization }
      its(["--email"]) { should eq :username }
      its(["-s"]) { should eq :space }
    end

    describe 'arguments' do
      subject(:arguments) { command.arguments }
      it 'have the correct commands' do
        expect(arguments).to eq [{:type => :optional, :value => :email, :name => :username}]
      end
    end
  end

  describe "running the command" do
    stub_home_dir_with("new")

    let(:auth_token) { CFoundry::AuthToken.new("bearer some-new-access-token", "some-new-refresh-token") }
    let(:tokens_yaml) { YAML.load_file(File.expand_path(tokens_file_path)) }
    let(:tokens_file_path) { '~/.vmc/tokens.yml' }
    let(:organizations) { [] }

    before do
      any_instance_of(CFoundry::V2::Client) do |client|
        stub(client).login("my-username", "my-password") { auth_token }
        stub(client).login_prompts do
          {
            :username => ["text", "Username"],
            :password => ["password", "8-digit PIN"]
          }
        end
        stub(client).organizations { [] }
      end
    end

    subject { vmc ["login", "--no-force"] }

    it "logs in with the provided credentials and saves the token data to the YAML file" do
      stub_ask("Username", {}) { "my-username" }
      stub_ask("8-digit PIN", {:echo => "*", :forget => true}) { "my-password" }

      subject

      expect(tokens_yaml["https://api.some-domain.com"][:token]).to eq("bearer some-new-access-token")
      expect(tokens_yaml["https://api.some-domain.com"][:refresh_token]).to eq("some-new-refresh-token")
    end

    context "with space and org in the token file" do
      before do
        write_token_file({:space => "space-id-1", :organization => "organization-id-1"})
        stub_ask("Username", {}) { "my-username" }
        stub_ask("8-digit PIN", {:echo => "*", :forget => true}) { "my-password" }
      end

      context "when the user has no organizations" do
        it "clears the org and space param from the token file" do
          subject

          expect(tokens_yaml["https://api.some-domain.com"][:space]).to be_nil
          expect(tokens_yaml["https://api.some-domain.com"][:organization]).to be_nil
        end
      end

      context "when the user has an organization, but no spaces" do
        before do
          stub.proxy(client).organization { organization }
          any_instance_of(described_class) do |instance|
            stub(instance).client { client }
          end
        end

        let(:client) { fake_client :organizations => organizations,
          :token => CFoundry::AuthToken.new("bearer some-access-token") }
        let(:organization) { OpenStruct.new(:name => 'My Org', :guid => 'organization-id-1', :users => [user]) }
        let(:user) { stub }

        before do
          stub(organization).spaces { [] }
        end

        shared_examples_for :method_clearing_the_token_file do
          it "sets the new organization in the token file" do
            subject
            expect(tokens_yaml["https://api.some-domain.com"][:organization]).to eq(organizations.first.guid)
          end

          it "clears the space param from the token file" do
            subject
            expect(tokens_yaml["https://api.some-domain.com"][:space]).to be_nil
          end
        end

        context "with one organization" do
          let(:organizations) {
            [ organization ]
          }

          it "does not prompt for an organization" do
            dont_allow_ask("Organization", anything)
            subject
          end

          it_behaves_like :method_clearing_the_token_file
        end

        context "with multiple organizations" do
          let(:organizations) {
            [ organization, OpenStruct.new(:name => 'My Org 2', :guid => 'organization-id-2') ]
          }

          before do
            stub_ask("Organization", anything) { organizations.first }
          end

          it "prompts for organization" do
            mock_ask("Organization", anything) { organizations.first }
            subject
          end

          it_behaves_like :method_clearing_the_token_file
        end
      end
    end

    context 'when there is no target' do
      let(:client) { nil }

      it "tells the user to run 'vmc target'" do
        expect { subject }.to raise_error(VMC::UserError)
      end
    end
  end
end
