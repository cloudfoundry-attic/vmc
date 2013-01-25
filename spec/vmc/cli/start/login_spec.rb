require 'spec_helper'

describe VMC::Start::Login do
  describe 'metadata' do
    let(:command) { Mothership.commands[:login] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Authenticate with the target" }
      it { expect(Mothership::Help.group(:start)).to include(subject) }
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
      subject { command.arguments }
      it 'have the correct commands' do
        should eq [{:type=>:optional, :value=>:email, :name=>:username}]
      end
    end
  end

  describe "running the command" do
    use_fake_home_dir { home_dir }

    let(:home_dir) do
      tmp_root = Dir.tmpdir
      FileUtils.cp_r(File.expand_path("#{SPEC_ROOT}/fixtures/fake_home_dirs/new"), tmp_root)
      "#{tmp_root}/new"
    end

    let(:auth_token) { CFoundry::AuthToken.new("bearer some-new-access-token", "some-new-refresh-token") }

    after { FileUtils.rm_rf home_dir }

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
      stub_ask("8-digit PIN", { :echo => "*", :forget => true}) { "my-password" }

      subject

      tokens_yaml = YAML.load_file(File.expand_path("~/.vmc/tokens.yml"))
      expect(tokens_yaml["https://api.some-domain.com"][:token]).to eq("bearer some-new-access-token")
      expect(tokens_yaml["https://api.some-domain.com"][:refresh_token]).to eq("some-new-refresh-token")
    end
  end
end