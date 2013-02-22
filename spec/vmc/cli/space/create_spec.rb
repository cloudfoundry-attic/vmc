require 'spec_helper'
require "vmc/cli/space/create"

describe VMC::Space::Create do
  let(:spaces) { fake_list(:space, 3) }
  let(:organization) { fake(:organization, :spaces => spaces) }
  let(:new_space) { stub! }
  let(:client) { fake_client(:current_organization => organization, :spaces => spaces) }
  let(:new_name) { "some-new-name" }

  before do
    %w{create! organization= name= name add_manager add_developer add_auditor organization}.each do |method|
      new_space.__send__(method.to_sym)
    end

    stub(client).space { new_space }
    any_instance_of described_class do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:create_space] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Create a space in an organization" }
      it { expect(Mothership::Help.group(:spaces)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([
          { :type => :optional, :value => nil, :name => :name },
          { :type => :optional, :value => nil, :name => :organization }
        ])
      end
    end
  end

  context "when we don't specify an organization" do
    subject { vmc %W[--no-quiet create-space new-space-name] }

    context "when we have a default organization" do
      it "uses that organization to create a space" do
        subject

        stdout.rewind
        expect(stdout.readline).to include "Creating space"
      end
    end

    context "when we don't have a default organization" do
      let(:organization) { nil }

      it "shows the help for the command" do
        subject

        stdout.rewind
        expect(stdout.readline).to include "Create a space in an organization"
      end

      it "does not try to create the space" do
        new_space.create! { raise "should not call this method" }
        subject
      end
    end
  end
end
