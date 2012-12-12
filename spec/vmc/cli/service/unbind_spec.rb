require 'spec_helper'

describe VMC::Service::Unbind do
  describe 'metadata' do
    let(:command) { Mothership.commands[:unbind_service] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Unbind a service from an application" }
      it { expect(Mothership::Help.group(:services, :manage)).to include(subject) }
    end

    describe 'inputs' do
      subject { command.inputs }

      it "is not missing any descriptions" do
        subject.each do |input, attrs|
          expect(attrs[:description]).to be
          expect(attrs[:description].strip).to_not be_empty
        end
      end
    end

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