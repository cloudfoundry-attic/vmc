require 'spec_helper'

describe VMC::Service::Unbind do
  describe 'metadata' do
    let(:command) { Mothership.commands[:unbind_service] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Unbind a service from an application" }
      it { expect(Mothership::Help.group(:services, :manage)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([
          { :type => :optional, :value => nil, :name => :service },
          { :type => :optional, :value => nil, :name => :app }
        ])
      end
    end
  end
end