require 'spec_helper'

describe VMC::Start::Target do
  describe 'metadata' do
    let(:command) { Mothership.commands[:target] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Set or display the target cloud, organization, and space" }
      specify { expect(Mothership::Help.group(:start)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'flags' do
      subject { command.flags }

      its(["-o"]) { should eq :organization }
      its(["--org"]) { should eq :organization }
      its(["-s"]) { should eq :space }
    end

    describe 'arguments' do
      subject(:arguments) { command.arguments }
      it 'have the correct commands' do
        expect(arguments).to eq [{:type => :optional, :value => nil, :name => :url}]
      end
    end
  end

  describe 'running the command' do
    stub_home_dir_with("new")

    context "when the user is authenticated and has an organization" do
      let(:tokens_file_path) { '~/.vmc/tokens.yml' }
      let(:organizations) {
        [ fake(:organization, :name => 'My Org', :guid => 'organization-id-1', :users => [user], :spaces => spaces),
          fake(:organization, :name => 'My Org 2', :guid => 'organization-id-2') ]
      }
      let(:spaces) {
        [ fake(:space, :name => 'Development', :guid => 'space-id-1'),
          fake(:space, :name => 'Staging',     :guid => 'space-id-2') ]
      }

      let(:user) { stub! }
      let(:organization) { organizations.first }
      let(:client) do
        fake_client :frameworks => fake_list(:framework, 3),
          :organizations => organizations,
          :token => CFoundry::AuthToken.new("bearer some-access-token")
      end

      before do
        write_token_file({:space => "space-id-1", :organization => "organization-id-1"})
        stub(client).current_user { user }
        stub(client).organization { organization }
        stub(client).current_organization { organization }
        any_instance_of(described_class) do |instance|
          stub(instance).client { client }
        end
      end

      describe "switching the space" do
        let(:space_name) { spaces.last.name }
        let(:tokens_yaml) { YAML.load_file(File.expand_path(tokens_file_path)) }
        let(:tokens_file_path) { '~/.vmc/tokens.yml' }

        def run_command
          vmc ["target", "-s", space_name]
        end

        it "should not reprompt for organization" do
          dont_allow_ask("Organization", anything)
          run_command
        end

        it "sets the space param in the token file" do
          run_command
          expect(tokens_yaml["https://api.some-domain.com"][:space]).to be == 'space-id-2'
        end
      end
    end
  end
end
