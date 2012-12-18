require 'spec_helper'

describe VMC::Service::Bind do
  describe 'metadata' do
    let(:command) { Mothership.commands[:bind_service] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Bind a service to an application" }
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