require 'spec_helper'

describe VMC::User::Register do
  describe 'metadata' do
    let(:command) { Mothership.commands[:register] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Create a user and log in" }
      it { expect(Mothership::Help.group(:admin, :user)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'have the correct commands' do
        should eq [
          {:type => :optional, :value => nil, :name => :email}
        ]
      end
    end
  end

  describe '#register' do
    let(:client) { fake_client }
    let(:email) { 'a@b.com' }
    let(:password) { 'password' }
    let(:verify_password) { password }
    let(:force) { false }
    let(:login) { false }
    let(:score) { :strong }

    before do
      any_instance_of described_class do |cli|
        stub(cli).client { client }
        stub(cli).precondition { nil }
      end
      stub(client).register
      stub(client).base.stub!.uaa.stub!.password_score(password) { score }
    end

    subject { vmc %W[register --email #{email} --password #{password} --verify #{verify_password} --#{bool_flag(:login)} --#{bool_flag(:force)}] }

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
        dont_allow(client).register
        any_instance_of(described_class) do |register|
          dont_allow(register).invoke
        end
        subject
      end

      context 'and the force flag is passed' do
        let(:force) { true }

        it "doesn't verify the password" do
          mock(client).register(email, password)
          subject
          expect(stderr.string).not_to include "Passwords do not match."
        end
      end
    end

    context 'when the password is good or strong' do
      it { should eq 0 }

      it 'prints out the password score' do
        subject
        expect(stdout.string).to include "Your password strength is: strong"
      end

      it 'registers the user' do
        mock(client).register(email, password)
        subject
      end

      context 'and the login flag is true' do
        let(:login) { true }

        it 'logs in' do
          any_instance_of(described_class) do |register|
            mock(register).invoke(:login, :username => email, :password => password)
          end
          subject
        end
      end

      context 'and the login flag is false' do
        it "doesn't log in" do
          any_instance_of(described_class) do |register|
            dont_allow(register).invoke(:login, :username => email, :password => password)
          end
          subject
        end
      end
    end

    context 'when the password is weak' do
      let(:score) { :weak }
      let(:login) { true }

      it { should eq 1 }

      it 'prints out the password score' do
        subject
        expect(stderr.string).to include "Your password strength is: weak"
      end

      it "doesn't register" do
        dont_allow(client).register(email, password)
        subject
      end

      it "doesn't log in" do
        any_instance_of(described_class) do |register|
          dont_allow(register).invoke(:login, :username => email, :password => password)
        end
        subject
      end
    end

    context 'when arguments are not passed in the command line' do
      subject { vmc %W[register --no-force --no-login] }

      it 'asks for the email, password and confirm password' do
        mock_ask("Email") { email }
        mock_ask("Password", anything) { password }
        mock_ask("Confirm Password", anything) { verify_password }
        subject
      end
    end
  end
end
