require 'spec_helper'

describe VMC::Service::Delete do
  describe 'metadata' do
    let(:command) { Mothership.commands[:delete_service] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Delete a service" }
      it { expect(Mothership::Help.group(:services, :manage)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{:type => :optional, :value => nil, :name => :service }])
      end
    end
  end
end