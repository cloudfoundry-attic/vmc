require 'spec_helper'

describe VMC::Start::Logout do
  let(:client) { fake_client }

  before do
    any_instance_of described_class do |cli|
      stub(cli).client { client }
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
      it_behaves_like "an error that gets passed through",
        :with_exception => VMC::UserError,
        :with_message => "Please select a target with 'vmc target'."
    end
  end
end

