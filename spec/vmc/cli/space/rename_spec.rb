require 'spec_helper'
require "vmc/cli/space/rename"

describe VMC::Space::Rename do
  let(:spaces) { fake_list(:space, 3) }
  let(:organization) { fake(:organization, :spaces => spaces) }
  let(:client) { fake_client(:current_organization => organization, :spaces => spaces) }
  let(:new_name) { "some-new-name" }

  before do
    any_instance_of described_class do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:rename_space] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Rename a space" }
      it { expect(Mothership::Help.group(:spaces)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([
          { :type => :optional, :value => nil, :name => :space },
          { :type => :optional, :value => nil, :name => :name }
        ])
      end
    end
  end

  context 'when there are no spaces' do
    let(:spaces) { [] }

    context 'and a space is given' do
      subject { vmc %W[rename-space --space some-invalid-space --no-force --no-quiet] }
      it 'prints out an error message' do
        subject
        expect(stderr.string).to include "Unknown space 'some-invalid-space'."
      end
    end

    context 'and a space is not given' do
      subject { vmc %W[rename-space --no-force] }
      it 'prints out an error message' do
        subject
        expect(stderr.string).to include "No spaces."
      end
    end
  end

  context 'when there are spaces' do
    let(:renamed_space) { spaces.first }

    context 'when the defaults are used' do
      subject { vmc %W[rename-space --no-force --no-quiet] }

      it 'asks for the space and new name and renames' do
        mock_ask("Rename which space?", anything) { renamed_space }
        mock_ask("New name") { new_name }
        mock(renamed_space).name=(new_name)
        mock(renamed_space).update!
        subject
      end
    end

    context 'when no name is provided, but a space is' do
      subject { vmc %W[rename-space --space #{renamed_space.name} --no-force] }

      it 'asks for the new name and renames' do
        dont_allow_ask("Rename which space?", anything)
        mock_ask("New name") { new_name }
        mock(renamed_space).name=(new_name)
        mock(renamed_space).update!
        subject
      end
    end

    context 'when a space is provided and a name' do
      subject { vmc %W[rename-space --space #{renamed_space.name} --name #{new_name} --no-force] }

      it 'renames the space' do
        mock(renamed_space).update!
        subject
      end

      it 'displays the progress' do
        mock_with_progress("Renaming to #{new_name}")
        mock(renamed_space).update!

        subject
      end

      context 'and the name already exists' do
        it 'fails' do
          mock(renamed_space).update! { raise CFoundry::SpaceNameTaken.new("Taken", 404) }
          subject
          expect(stderr.string).to include "404: Taken"
        end
      end
    end
  end
end
