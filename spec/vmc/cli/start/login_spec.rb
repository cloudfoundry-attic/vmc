require 'spec_helper'

describe VMC::Start::Login do
  describe 'metadata' do
    let(:command) { Mothership.commands[:login] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Authenticate with the target" }
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

      its(["-o"]) { should eq :organization }
      its(["--org"]) { should eq :organization }
      its(["--email"]) { should eq :username }
      its(["-s"]) { should eq :space }
    end

    describe 'arguments' do
      subject { command.arguments }
      it 'have the correct commands' do
        should eq [{:type=>:optional, :value=>:email, :name=>:username}]
      end
    end
  end
end