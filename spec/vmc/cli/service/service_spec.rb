require 'spec_helper'

describe VMC::Service::Service do
  describe 'metadata' do
    let(:command) { Mothership.commands[:service] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Show service information" }
      it { expect(Mothership::Help.group(:services)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{:type => :required, :value=>nil, :name=>:service}])
      end
    end
  end
end

