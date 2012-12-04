require 'spec_helper'
require "vmc/cli/app/push"

describe VMC::App::Push do
  let(:global_inputs) { { :color => false, :quiet => true } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:client) { FactoryGirl.build(:client) }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  describe 'CLI' do
    subject { Mothership.new.invoke(:push, inputs, given, global_inputs) }

    context 'when creating a new app' do
    end

    context 'when syncing an existing app' do
    end
  end

  describe '#create_app' do
    it 'should detect the correct framework'
  end

  describe '#sync_app' do
    let(:app) { FactoryGirl.build(:app) }
    let(:push) { VMC::App::Push.new }

    subject do
      push.input = Mothership::Inputs.new(nil, push, inputs, {}, global_inputs)
      push.sync_app(app)
    end

    shared_examples 'common tests for inputs' do |*args|
      context 'when the new input is the same as the old' do
        type, input = args
        input ||= type

        let(:inputs) { {input => old} }

        it "does not update the app's #{type}" do
          dont_allow(push).line
          dont_allow(app).update!
          expect { subject }.not_to change { app.send(type) }
        end
      end
    end

    context 'when no inputs are given' do
      let(:inputs) { {} }

      it 'should not update the app' do
        dont_allow(app).update!
        subject
      end

      [:memory=, :framework=].each do |property|
        it "should not set #{property} on the app" do
          dont_allow(app).__send__(property)
          subject
        end
      end
    end

    context 'when memory is given' do
      let(:old) { 1024 }
      let(:new) { "2G" }
      let(:app) { FactoryGirl.build(:app, :memory => old) }
      let(:inputs) { { :memory => new } }

      it 'updates the app memory, converting to megabytes' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.memory }.from(old).to(2048)
      end

      it 'outputs the changed memory in human readable sizes' do
        mock(push).line("Changes:")
        mock(push).line("memory: 1G -> 2G")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :memory
    end

    context 'when instances is given' do
      let(:old) { 1 }
      let(:new) { 2 }
      let(:app) { FactoryGirl.build(:app, :total_instances => old) }
      let(:inputs) { { :instances => new } }

      it 'updates the app instances' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.total_instances }.from(old).to(new)
      end

      it 'outputs the changed instances' do
        mock(push).line("Changes:")
        mock(push).line("instances: 1 -> 2")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :total_instances, :instances
    end

    context 'when framework is given' do
      let(:old) { FactoryGirl.build(:framework, :name => "Old Framework") }
      let(:new) { FactoryGirl.build(:framework, :name => "New Framework") }
      let(:app) { FactoryGirl.build(:app, :framework => old) }
      let(:inputs) { { :framework => new} }

      it 'updates the app framework' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.framework }.from(old).to(new)
      end

      it 'outputs the changed framework using the name' do
        mock(push).line("Changes:")
        mock(push).line("framework: Old Framework -> New Framework")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :framework
    end

    context 'when runtime is given' do
      let(:old) { FactoryGirl.build(:runtime, :name => "Old Runtime") }
      let(:new) { FactoryGirl.build(:runtime, :name => "New Runtime") }
      let(:app) { FactoryGirl.build(:app, :runtime => old) }
      let(:inputs) { { :runtime => new } }

      it 'updates the app runtime' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.runtime }.from(old).to(new)
      end

      it 'outputs the changed runtime using the name' do
        mock(push).line("Changes:")
        mock(push).line("runtime: Old Runtime -> New Runtime")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :runtime
    end

    context 'when command is given' do
      let(:old) { "./start" }
      let(:new) { "./start foo " }
      let(:app) { FactoryGirl.build(:app, :command => old) }
      let(:inputs) { { :command => new } }

      it 'updates the app command' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.command }.from("./start").to("./start foo ")
      end

      it 'outputs the changed command in single quotes' do
        mock(push).line("Changes:")
        mock(push).line("command: './start' -> './start foo '")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :command
    end

    context 'when plan is given' do
      let(:old) { false }
      let(:new) { "p100" }
      let(:inputs) { { :plan => new } }

      include_examples 'common tests for inputs', :production, :plan

      %w{p100 P100 P200}.each do |plan|
        context "when the given plan is #{plan}" do
          let(:inputs) { { :plan => plan } }
        
          it 'sets production to true' do
            stub(push).line(anything)
            mock(app).update!          
            expect { subject }.to change { app.production }.from(false).to(true)
          end

          it 'outputs the changed plan in single quotes' do
            mock(push).line("Changes:")
            mock(push).line("production: false -> true")
            stub(app).update!
            subject
          end
        end
      end

      %w{d100 D100 D200 fizzbuzz}.each do |plan|
        context "when the given plan is #{plan}" do
          let(:app) { FactoryGirl.build(:app, :production => true) }

          let(:inputs) { { :plan => plan } }
        
          it 'sets production to false' do
            stub(push).line(anything)
            mock(app).update!          
            expect { subject }.to change { app.production }.from(true).to(false)
          end

          it 'outputs the changed plan in single quotes' do
            mock(push).line("Changes:")
            mock(push).line("production: true -> false")
            stub(app).update!
            subject
          end
        end
      end
    end
  end
end
