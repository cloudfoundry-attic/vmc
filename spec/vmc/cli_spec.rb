require 'spec_helper'

describe VMC::CLI do
  let(:cmd) { Class.new(VMC::CLI).new }

  describe '#execute' do
    let(:inputs) { {} }

    subject do
      capture_output do
        stub(cmd).input { inputs }
        cmd.execute(nil, [])
      end
    end

    it 'wraps Timeout::Error with a more friendly message' do
      stub(cmd).precondition { raise CFoundry::Timeout.new(Net::HTTP::Get, "/foo") }

      mock(cmd).err 'GET /foo timed out'
      subject
    end

    context 'when the debug flag is on' do
      let(:inputs) { {:debug => true} }

      it 'reraises' do
        stub(cmd).precondition { raise StandardError.new }
        expect { subject }.to raise_error(StandardError)
      end
    end

    context 'when the debug flag is off' do
      it 'outputs the crash log message' do
        stub(cmd).precondition { raise StandardError.new }
        mock(cmd).err /StandardError: StandardError\nFor more information, see .+\.vmc\/crash/

        expect { subject }.not_to raise_error(StandardError)
      end
    end
  end

  describe '#log_error' do
    subject do
      cmd.log_error(exception)
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
      let(:request) { Net::HTTP::Get.new("http://api.cloudfoundry.com/foo") }
      let(:response) { Net::HTTPNotFound.new("foo", 404, "bar")}
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
    subject { VMC::CLI.new.client_target }

    context "when a ~/.vmc/target exists" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/new" }

      it "returns the target in that file" do
        expect(subject).to eq "https://api.some-domain.com"
      end
    end

    context "when a ~/.vmc_target exists" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/old" }

      it "returns the target in that file" do
        expect(subject).to eq "https://api.some-domain.com"
      end
    end

    context "when no target file exists" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/no_config" }

      it "displays an error to the user" do
        expect{ subject }.to raise_error(VMC::UserError, /Please select a target/)
      end
    end
  end

  describe "#targets_info" do
    subject { VMC::CLI.new.targets_info }

    context "when a ~/.vmc/tokens.yml exists" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/new" }

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
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/old" }

      it "returns the target in that file" do
        expect(subject).to eq({
          "https://api.some-domain.com" => {
            :token => "bearer some-token"
          }
        })
      end
    end

    context "when no token file exists" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/no_config" }

      it "returns an empty hash" do
        expect(subject).to eq({})
      end
    end
  end

  describe "#target_info" do
    subject { VMC::CLI.new.target_info("https://api.some-domain.com") }

    context "when a ~/.vmc/tokens.yml exists" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/new" }

      it "returns the info for the given url" do
        expect(subject).to eq({
          :token => "bearer some-token",
          :version => 2
        })
      end
    end

    context "when a ~/.vmc_token file exists" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/old" }

      it "returns the info for the given url" do
        expect(subject).to eq({
          :token => "bearer some-token"
        })
      end
    end

    context "when no token file exists" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/no_config" }

      it "returns an empty hash" do
        expect(subject).to eq({})
      end
    end
  end

  describe "methods that update the token info" do
    let!(:tmpdir) { Dir.mktmpdir }
    let(:cli) { VMC::CLI.new }
    use_fake_home_dir { tmpdir }

    before do
      stub(cli).targets_info do
        {
          "https://api.some-domain.com" => { :token => "bearer token1" },
          "https://api.some-other-domain.com" => { :token => "bearer token2" }
        }
      end
    end

    after { FileUtils.rm_rf tmpdir }

    describe "#save_target_info" do
      it "adds the given target info, and writes the result to ~/.vmc/tokens.yml" do
        cli.save_target_info({ :token => "bearer token3" }, "https://api.some-domain.com")
        YAML.load_file(File.expand_path("~/.vmc/tokens.yml")).should == {
          "https://api.some-domain.com" => { :token => "bearer token3" },
          "https://api.some-other-domain.com" => { :token => "bearer token2" }
        }
      end
    end

    describe "#remove_target_info" do
      it "removes the given target, and writes the result to ~/.vmc/tokens.yml" do
        cli.remove_target_info("https://api.some-domain.com")
        YAML.load_file(File.expand_path("~/.vmc/tokens.yml")).should == {
          "https://api.some-other-domain.com" => { :token => "bearer token2" }
        }
      end
    end
  end
end

