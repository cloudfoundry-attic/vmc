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

      mock(cmd).err "GET /foo timed out"
      subject
    end

    context "when the debug flag is on" do
      let(:inputs) { {:debug => true} }

      it 'reraises' do
        stub(cmd).precondition { raise StandardError.new }
        expect { subject }.to raise_error(StandardError)
      end
    end

    context "when the debug flag is off" do
      it 'outputs the crash log message' do
        stub(cmd).precondition { raise StandardError.new }
        mock(cmd).err /StandardError: StandardError\nFor more information, see .+\.vmc\/crash/

        expect { subject }.not_to raise_error(StandardError)
      end
    end
  end
end

