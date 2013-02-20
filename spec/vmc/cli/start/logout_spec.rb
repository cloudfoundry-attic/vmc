require 'spec_helper'

describe VMC::Start::Logout do
  let(:client) { fake_client }

  before do
    any_instance_of described_class do |cli|
      stub(cli).client { client }
    end

    described_class.class_eval do
      def wrap_errors
        yield
      end
    end
  end

  after do
    described_class.class_eval do
      remove_method :wrap_errors
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:logout] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Log out from the target" }
      it { expect(Mothership::Help.group(:start)).to include(subject) }
    end
  end

  describe "running the command" do
    subject { vmc ["logout"] }

    context "when there is a target" do
      let(:info) { { client.target => "x", "abc" => "x" } }

      before do
        any_instance_of VMC::CLI do |cli|
          stub(cli).targets_info { info }
          stub(cli).client_target { client.target }
        end
      end

      it "removes the target info from the tokens file" do
        expect {
          subject
        }.to change { info }.to("abc" => "x")
      end
    end

    context "when there is no target" do
      let(:client) { nil }

      it "tells the user to run 'vmc target'" do
        expect { subject }.to raise_error(VMC::UserError)
      end
    end
  end
end

