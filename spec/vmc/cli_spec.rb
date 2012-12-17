require 'spec_helper'

describe VMC::CLI do
  let(:cmd) { Class.new(VMC::CLI).new }

  describe '#execute' do
    subject do
      stub(cmd).input { {} }
      cmd.execute(nil, [])
    end

    it 'wraps Timeout::Error with a more friendly message' do
      stub(cmd).precondition { raise CFoundry::Timeout.new(Net::HTTP::Get, "/foo") }

      mock(cmd).err "GET /foo timed out"
      subject
    end
  end
end

