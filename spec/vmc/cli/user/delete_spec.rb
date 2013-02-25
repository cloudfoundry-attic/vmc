require 'spec_helper'
require "vmc/cli/user/delete"

describe VMC::User::Delete do
  let(:global) { { :color => false, :quiet => true } }
  let(:inputs) { { :email => "user@example.com"} }
  let(:given) { {} }
  let(:client) { fake_client }
  let(:app) {}

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
    end
  end

  subject { Mothership.new.invoke(:delete_user, inputs, given, global) }

  describe 'metadata' do
    let(:command) { Mothership.commands[:delete_user] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Delete a user" }
      it { expect(Mothership::Help.group(:admin, :user)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([
          { :type => :normal, :value => nil, :name => :email }
        ])
      end
    end
  end

  describe "deleting a user" do
    context "when targeting a V2 API" do
      before do
        stub(client).version { 2 }
      end

      it_behaves_like "an error that gets passed through",
        :with_exception => VMC::UserError,
        :with_message => "Not implemented for v2."
    end
  end
end
