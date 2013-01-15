require 'spec_helper'
require "vmc/cli/app/rename"

describe VMC::App::Rename do
  let(:global) { { :color => false, :quiet => true } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:client) { fake_client }
  let(:app) {}
  let(:new_name) { "some-new-name" }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  subject { Mothership.new.invoke(:rename, inputs, given, global) }

  describe 'metadata' do
    let(:command) { Mothership.commands[:rename] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Rename an application" }
      it { expect(Mothership::Help.group(:apps, :manage)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([
          { :type => :optional, :value => nil, :name => :app },
          { :type => :optional, :value => nil, :name => :name }
        ])
      end
    end
  end

  context 'when there are no apps' do
    context 'and an app is given' do
      let(:given) { { :app => "some-app" } }
      it { expect { subject }.to raise_error(VMC::UserError, "Unknown app 'some-app'.") }
    end

    context 'and an app is not given' do
      it { expect { subject }.to raise_error(VMC::UserError, "No applications.") }
    end
  end

  context 'when there are apps' do
    let(:client) { fake_client(:apps => apps) }
    let(:apps) { fake_list(:app, 2) }
    let(:renamed_app) { apps.first }

    context 'when the defaults are used' do
      it 'asks for the app and new name and renames' do
        mock_ask("Rename which application?", anything) { renamed_app }
        mock_ask("New name") { new_name }
        mock(renamed_app).name=(new_name)
        mock(renamed_app).update!
        subject
      end
    end

    context 'when no name is provided, but a app is' do
      let(:given) { { :app => renamed_app.name } }

      it 'asks for the new name and renames' do
        dont_allow_ask("Rename which application?", anything)
        mock_ask("New name") { new_name }
        mock(renamed_app).name=(new_name)
        mock(renamed_app).update!
        subject
      end
    end

    context 'when an app is provided and a name' do
      let(:inputs) { { :app => renamed_app, :name => new_name } }

      it 'renames the app' do
        mock(renamed_app).update!
        subject
      end

      it 'displays the progress' do
        mock_with_progress("Renaming to #{new_name}")
        mock(renamed_app).update!

        subject
      end

      context 'and the name already exists' do
        it 'fails' do
          mock(renamed_app).update! { raise CFoundry::AppNameTaken.new("Bad Name", 404) }
          expect { subject }.to raise_error(CFoundry::AppNameTaken)
        end
      end
    end
  end
end
