require 'spec_helper'

describe VMC::Start::Info do
  describe 'metadata' do
    let(:command) { Mothership.commands[:info] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Display information on the current target, user, etc." }
      it { expect(Mothership::Help.group(:start)).to include(subject) }
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

    describe 'flags' do
      subject { command.flags }

      its(["-f"]) { should eq :frameworks }
      its(["-r"]) { should eq :runtimes }
      its(["-s"]) { should eq :services }
      its(["-a"]) { should eq :all }
    end

    describe 'arguments' do
      subject { command.arguments }
      it { should be_empty }
    end
  end
end