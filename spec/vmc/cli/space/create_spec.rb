require 'spec_helper'
require "vmc/cli/space/create"

command VMC::Space::Create do
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

  describe "running the command" do
    let(:client) do
      fake_client(:current_organization => organization)
    end

    let(:organization) { fake(:organization) }

    let(:new_space) { fake :space, :name => new_name }
    let(:new_name) { "some-new-name" }

    before do
      stub(client).space { new_space }
      stub(new_space).create!
      stub(new_space).add_manager
      stub(new_space).add_developer
      stub(new_space).add_auditor
    end

    context "when --target is given" do
      subject { vmc %W[create-space #{new_space.name} --target] }

      it "switches them to the new space" do
        mock_invoke :target, :organization => organization,
          :space => new_space
        subject
      end
    end

    context "when --target is NOT given" do
      subject { vmc %W[create-space #{new_space.name}] }

      it "tells the user how they can switch to the new space" do
        subject
        expect(output).to say("Space created! Use switch-space #{new_space.name} to target it.")
      end
    end

    context "when we don't specify an organization" do
      subject { vmc %W[create-space #{new_space.name}] }

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
          new_space.create! { raise "should not call this method" } # rr not behaving
          subject
        end
      end
    end
  end
end
