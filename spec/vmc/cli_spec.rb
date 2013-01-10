require 'spec_helper'

describe VMC::CLI do
  let(:cmd) { Class.new(VMC::CLI).new }

  describe '#execute' do
    let(:inputs) { {} }

    subject do
      with_output_to do
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
      File.read(VMC::CRASH_FILE)
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
        error = CFoundry::APIError.new(request, response)
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
end

