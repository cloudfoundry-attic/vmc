require 'spec_helper'

describe VMC::User::Passwd do
  describe 'metadata' do
    let(:command) { Mothership.commands[:passwd] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Update a user's password" }
      it { expect(Mothership::Help.group(:admin, :user)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'have the correct commands (with inconsistent user instead of email)' do
        should eq [{:type => :optional, :value => nil, :name => :user}]
      end
    end
  end

  describe '#passwd' do
    let(:client) { fake_client }
    let(:old_password) { "old" }
    let(:new_password) { "password" }
    let(:verify_password) { new_password }
    let(:score) { :strong }
    let(:guid) { random_string("my-object-guid") }
    let(:user_model) { fake_model { attribute :password, :object } }
    let(:user_object) { user_model.new(guid, client) }
    let(:user) { user_object.fake(:password => 'foo') }

    before do
      any_instance_of described_class do |cli|
        stub(cli).client { client }
        stub(cli).precondition { nil }
      end
      stub(client).logged_in? { true }
      stub(client).current_user { user }
      stub(client).register
      stub(client).base.stub!.uaa.stub!.password_score(new_password) { score }
    end

    subject { vmc %W[passwd --password #{old_password} --new-password #{new_password} --verify #{verify_password} --no-force --debug] }

    context 'when the passwords dont match' do
      let(:verify_password) { "other_password" }

      it { should eq 1 }

      it 'fails' do
        subject
        expect(stderr.string).to include "Passwords do not match."
      end

      it "doesn't print out the score" do
        subject
        expect(stdout.string).not_to include "strength"
      end

      it "doesn't log in or register" do
        dont_allow(user).change_password!
        subject
      end
    end

    context 'when the password is good or strong' do
      before do
        stub(user).change_password!
      end

      it { should eq 0 }

      it 'prints out the password score' do
        subject
        expect(stdout.string).to include "Your password strength is: strong"
      end

      it 'changes the password' do
        mock(user).change_password!(new_password, old_password)
        subject
      end
    end

    context 'when the password is weak' do
      let(:score) { :weak }

      it { should eq 1 }

      it 'prints out the password score' do
        subject
        expect(stderr.string).to include "Your password strength is: weak"
      end

      it "doesn't change the password" do
        dont_allow(user).change_password!
        subject
      end
    end
  end
end
