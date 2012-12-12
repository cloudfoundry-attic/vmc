require 'spec_helper'

describe VMC::Service::Service do
  describe 'metadata' do
    let(:command) { Mothership.commands[:service] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Show service information" }
      it { expect(Mothership::Help.group(:services)).to include(subject) }
    end

    describe 'inputs' do
      subject { command.inputs }

      it "is not missing any descriptions" do
        subject.each do |_, attrs|
          expect(attrs[:description]).to be
          expect(attrs[:description].strip).to_not be_empty
        end
      end
    end

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{:type => :required, :value=>nil, :name=>:service}])
      end
    end
  end
end

