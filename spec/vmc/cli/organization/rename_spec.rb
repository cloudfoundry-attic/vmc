require 'spec_helper'
require "vmc/cli/organization/rename"

describe VMC::Organization::Rename do
  let(:global) { { :color => false, :quiet => true } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:organizations) { fake_list(:organization, 3) }
  let(:client) { fake_client(:organizations => organizations) }
  let(:new_name) { "some-new-name" }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  subject { Mothership.new.invoke(:rename_org, inputs, given, global) }

  describe 'metadata' do
    let(:command) { Mothership.commands[:rename_org] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Rename an organization" }
      it { expect(Mothership::Help.group(:organizations)).to include(subject) }
    end

    describe 'inputs' do
      subject { command.inputs }

      it "is not missing any descriptions" do
        subject.each do |input, attrs|
          expect(attrs[:description]).to be
          expect(attrs[:description].strip).to_not be_empty
        end
      end
    end

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([
          { :type => :optional, :value => nil, :name => :organization },
          { :type => :optional, :value => nil, :name => :name }
        ])
      end
    end
  end

  context 'when there are no organizations' do
    let(:organizations) { [] }

    context 'and an organization is given' do
      let(:given) { { :organization => "some-invalid-organization" } }
      it { expect { subject }.to raise_error(VMC::UserError, "Unknown organization 'some-invalid-organization'.") }
    end

    context 'and an organization is not given' do
      it { expect { subject }.to raise_error(VMC::UserError, "No organizations.") }
    end
  end

  context 'when there are organizations' do
    let(:renamed_organization) { organizations.first }

    context 'when the defaults are used' do
      it 'asks for the organization and new name and renames' do
        mock_ask("Rename which organization?", anything) { renamed_organization }
        mock_ask("New name") { new_name }
        mock(renamed_organization).name=(new_name)
        mock(renamed_organization).update!
        subject
      end
    end

    context 'when no name is provided, but an organization is' do
      let(:given) { { :organization => renamed_organization.name } }

      it 'asks for the new name and renames' do
        dont_allow_ask("Rename which organization?", anything)
        mock_ask("New name") { new_name }
        mock(renamed_organization).name=(new_name)
        mock(renamed_organization).update!
        subject
      end
    end

    context 'when an organization is provided and a name' do
      let(:inputs) { { :organization => renamed_organization, :name => new_name } }

      it 'renames the organization' do
        mock(renamed_organization).update!
        subject
      end

      it 'displays the progress' do
        mock_with_progress("Renaming to #{new_name}")
        mock(renamed_organization).update!

        subject
      end

      context 'and the name already exists' do
        it 'fails' do
          mock(renamed_organization).update! { raise CFoundry::OrganizationNameTaken.new("Bad error", 200) }
          expect { subject }.to raise_error(CFoundry::OrganizationNameTaken)
        end
      end
    end
  end
end
