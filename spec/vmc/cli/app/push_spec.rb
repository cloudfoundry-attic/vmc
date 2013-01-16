require 'spec_helper'
require "vmc/cli/app/push"

describe VMC::App::Push do
  let(:global) { { :color => false, :quiet => true } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:path) { "somepath" }
  let(:client) { fake_client }
  let(:push) { VMC::App::Push.new(Mothership.commands[:push]) }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:push] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Push an application, syncing changes if it exists" }
      it { expect(Mothership::Help.group(:apps, :manage)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{ :type => :optional, :value => nil, :name => :name }])
      end
    end
  end

  describe '#sync_app' do
    let(:app) { fake(:app) }

    before do
      stub(app).upload
      app.changes = {}
    end

    subject do
      push.input = Mothership::Inputs.new(nil, push, inputs, {}, global)
      push.sync_app(app, path)
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

    it 'uploads the app' do
      mock(app).upload(path)
      subject
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
      let(:app) { fake(:app, :memory => old) }
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
      let(:app) { fake(:app, :total_instances => old) }
      let(:inputs) { { :instances => new } }

      it 'updates the app instances' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.total_instances }.from(old).to(new)
      end

      it 'outputs the changed instances' do
        mock(push).line("Changes:")
        mock(push).line("total_instances: 1 -> 2")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :total_instances, :instances
    end

    context 'when framework is given' do
      let(:old) { fake(:framework, :name => "Old Framework") }
      let(:new) { fake(:framework, :name => "New Framework") }
      let(:app) { fake(:app, :framework => old) }
      let(:inputs) { { :framework => new } }

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
      let(:old) { fake(:runtime, :name => "Old Runtime") }
      let(:new) { fake(:runtime, :name => "New Runtime") }
      let(:app) { fake(:app, :runtime => old) }
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
      let(:app) { fake(:app, :command => old) }
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
      let(:old) { "d100" }
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
          let(:app) { fake(:app, :production => true) }

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

    context 'when restart is given' do
      let(:inputs) { { :restart => true, :memory => 4096 } }


      context 'when the app is already started' do
        let(:app) { fake(:app, :state => "STARTED") }

        it 'invokes the restart command' do
          stub(push).line
          mock(app).update!
          mock(push).invoke(:restart, :app => app)
          subject
        end

        context 'but there are no changes' do
          let(:inputs) { { :restart => true } }

          it 'invokes the restart command' do
            stub(push).line
            dont_allow(app).update!
            mock(push).invoke(:restart, :app => app)
            subject
          end
        end
      end

      context 'when the app is not already started' do
        let(:app) { fake(:app, :state => "STOPPED") }

        it 'does not invoke the restart command' do
          stub(push).line
          mock(app).update!
          dont_allow(push).invoke(:restart, :app => app)
          subject
        end
      end
    end
  end

  describe '#setup_new_app (integration spec!!)' do
    let(:app) { fake(:app, :guid => nil) }
    let(:framework) { fake(:framework) }
    let(:runtime) { fake(:runtime) }
    let(:url) { "https://www.foobar.com" }
    let(:inputs) do
      { :name => "some-app",
        :instances => 2,
        :framework => framework,
        :runtime => runtime,
        :memory => 1024,
        :url => url
      }
    end
    let(:global) { {:quiet => true, :color => false, :force => true} }

    before do
      stub(client).app { app }
    end

    subject do
      push.input = Mothership::Inputs.new(Mothership.commands[:push], push, inputs, global, global)
      push.setup_new_app(path)
    end

    it 'creates the app' do
      mock(app).create!
      mock(app).upload(path)
      mock(push).filter(:create_app, app) { app }
      mock(push).filter(:push_app, app) { app }
      mock(push).invoke :map, :app => app, :url => url
      mock(push).invoke :start, :app => app
      subject
    end
  end
end
