require 'spec_helper'
require "vmc/cli/space/rename"

describe VMC::Space::Rename do
  let(:global) { { :color => false, :quiet => true } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:spaces) { FactoryGirl.build_list(:space, 3) }
  let(:organization) { FactoryGirl.build(:organization, :spaces => spaces) }
  let(:client) { FactoryGirl.build(:client, :current_organization => organization, :spaces => spaces) }
  let(:new_name) { "some-new-name" }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  subject { Mothership.new.invoke(:rename_space, inputs, given, global) }

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
      let(:given) { { :space => "some-invalid-space" } }
      it { expect { subject }.to raise_error(VMC::UserError, "Unknown space 'some-invalid-space'.") }
    end

    context 'and a space is not given' do
      it { expect { subject }.to raise_error(VMC::UserError, "No spaces.") }
    end
  end

  context 'when there are spaces' do
    let(:renamed_space) { spaces.first }

    context 'when the defaults are used' do
      it 'asks for the space and new name and renames' do
        mock_ask("Rename which space?", anything) { renamed_space }
        mock_ask("New name") { new_name }
        mock(renamed_space).name=(new_name)
        mock(renamed_space).update!
        subject
      end
    end

    context 'when no name is provided, but a space is' do
      let(:given) { { :space => renamed_space.name } }

      it 'asks for the new name and renames' do
        dont_allow_ask("Rename which space?", anything)
        mock_ask("New name") { new_name }
        mock(renamed_space).name=(new_name)
        mock(renamed_space).update!
        subject
      end
    end

    context 'when a space is provided and a name' do
      let(:inputs) { { :space => renamed_space, :name => new_name } }

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
          mock(renamed_space).update! { raise CFoundry::SpaceNameTaken }
          expect { subject }.to raise_error(CFoundry::SpaceNameTaken)
        end
      end
    end
  end
end
