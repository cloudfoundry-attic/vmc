require 'spec_helper'
require "vmc/cli/app/delete"

describe VMC::App::Delete do
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

  subject { Mothership.new.invoke(:delete, inputs, given, global) }

  describe 'metadata' do
    let(:command) { Mothership.commands[:delete] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Delete an application" }
      it { expect(Mothership::Help.group(:apps, :manage)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{ :type => :splat, :value => nil, :name => :apps }])
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
    let(:apps) { [basic_app, app_with_orphans, app_without_orphans] }
    let(:service_1) { fake :service_instance }
    let(:service_2) { fake :service_instance }
    let(:basic_app) { fake(:app, :name => "basic_app") }
    let(:app_with_orphans) {
      fake :app,
        :name => "app_with_orphans",
        :service_bindings => [
          fake(:service_binding, :service_instance => service_1),
          fake(:service_binding, :service_instance => service_2)
        ]
    }
    let(:app_without_orphans) {
      fake :app,
        :name => "app_without_orphans",
        :service_bindings => [
          fake(:service_binding, :service_instance => service_1)
        ]
    }

    context 'and no app is given' do
      it 'asks for the app' do
        mock_ask("Delete which application?", anything) { basic_app }
        stub_ask { true }
        stub(basic_app).delete!
        subject
      end
    end

    context 'and a basic app is given' do
      let(:deleted_app) { basic_app }
      let(:given) { { :app => deleted_app.name } }

      context 'and it asks for confirmation' do
        context 'and the user answers no' do
          it 'does not delete the application' do
            mock_ask("Really delete #{deleted_app.name}?", anything) { false }
            dont_allow(deleted_app).delete!
            subject
          end
        end

        context 'and the user answers yes' do
          it 'deletes the application' do
            mock_ask("Really delete #{deleted_app.name}?", anything) { true }
            mock(deleted_app).delete!
            subject
          end
        end
      end

      context 'and --force is given' do
        let(:global) { { :force => true, :color => false, :quiet => true } }

        it 'deletes the application without asking to confirm' do
          dont_allow_ask
          mock(deleted_app).delete!
          subject
        end
      end
    end

    context 'and an app with orphaned services is given' do
      let(:deleted_app) { app_with_orphans }
      let(:inputs) { { :app => deleted_app } }

      context 'and it asks for confirmation' do
        context 'and the user answers yes' do
          it 'asks to delete orphaned services' do
            stub_ask("Really delete #{deleted_app.name}?", anything) { true }
            stub(deleted_app).delete!

            stub(service_2).invalidate!

            mock_ask("Delete orphaned service #{service_2.name}?", anything) { true }

            any_instance_of(VMC::App::Delete) do |del|
              mock(del).invoke :delete_service, :service => service_2,
                :really => true
            end

            subject
          end
        end

        context 'and the user answers no' do
          it 'does not ask to delete orphaned serivces, or delete them' do
            stub_ask("Really delete #{deleted_app.name}?", anything) { false }
            dont_allow(deleted_app).delete!

            stub(service_2).invalidate!

            dont_allow_ask("Delete orphaned service #{service_2.name}?")

            any_instance_of(VMC::App::Delete) do |del|
              dont_allow(del).invoke(:delete_service, anything)
            end

            subject
          end
        end
      end

      context 'and --force is given' do
        let(:global) { { :force => true, :color => false, :quiet => true } }

        it 'does not delete orphaned services' do
          dont_allow_ask
          stub(deleted_app).delete!

          any_instance_of(VMC::App::Delete) do |del|
            dont_allow(del).invoke(:delete_service, anything)
          end

          subject
        end
      end

      context 'and --delete-orphaned is given' do
        let(:inputs) { { :app => deleted_app, :delete_orphaned => true } }

        it 'deletes the orphaned services' do
          stub_ask("Really delete #{deleted_app.name}?", anything) { true }
          stub(deleted_app).delete!

          any_instance_of(VMC::App::Delete) do |del|
            mock(del).invoke :delete_service, :service => service_2,
              :really => true
          end

          subject
        end
      end
    end
  end
end
