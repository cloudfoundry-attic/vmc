require 'spec_helper'

describe VMC::App::Create do
  let(:inputs) { {} }
  let(:given) { {} }
  let(:global) { { :color => false, :quiet => true } }

  let(:frameworks) { fake_list(:framework, 3) }
  let(:framework) { buildpack }
  let(:buildpack) { fake(:framework, :name => "buildpack") }
  let(:standalone) { fake(:framework, :name => "standalone") }

  let(:runtimes) { fake_list(:runtime, 3) }
  let(:runtime) { runtimes.first }

  let(:service_instances) { fake_list(:service_instance, 5) }

  let(:client) do
    fake_client(
      :frameworks => frameworks,
      :runtimes => runtimes,
      :service_instances => service_instances)
  end

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
    end
  end

  let(:create) do
    create = VMC::App::Push.new
    create.path = "some-path"
    create.input = Mothership::Inputs.new(Mothership.commands[:push], create, inputs, given, global)
    create.extend VMC::App::PushInteractions
    create
  end

  describe '#get_inputs' do
    subject { create.get_inputs }

    let(:inputs) do
      { :name => "some-name",
        :instances => 1,
        :plan => "p100",
        :framework => framework,
        :runtime => runtime,
        :memory => "1G",
        :command => "ruby main.rb",
        :buildpack => "git://example.com"
      }
    end

    context 'when all the inputs are given' do
      its([:name]) { should eq "some-name" }
      its([:total_instances]) { should eq 1 }
      its([:space]) { should eq client.current_space }
      its([:production]) { should eq true }
      its([:framework]) { should eq framework }
      its([:command]) { should eq "ruby main.rb" }
      its([:runtime]) { should eq runtime }
      its([:memory]) { should eq 1024 }
      its([:buildpack]) { should eq "git://example.com" }
    end

    context 'when certain inputs are not given' do
      it 'should ask for the name' do
        inputs.delete(:name)
        mock_ask("Name") { "some-name" }
        subject
      end

      it 'should ask for the total instances' do
        inputs.delete(:instances)
        mock_ask("Instances", anything) { 1 }
        subject
      end

      it 'should ask for the framework' do
        inputs.delete(:framework)
        mock_ask('Framework', anything) do |_, options|
          expect(options[:choices]).to eq frameworks.sort_by(&:name)
          framework
        end
        subject
      end

      context 'when the command is not given' do
        before { inputs.delete(:command) }

        shared_examples 'an app that can have a custom start command' do
          it 'should ask if there is a custom start command' do
            mock_ask("Use custom startup command?", :default => false) { false }
            subject
          end

          context 'when the user answers "yes" to the custom start command' do
            before { stub_ask("Use custom startup command?", :default => false) { true } }

            it 'should ask for the startup command' do
              mock_ask("Startup command") { "foo bar.com" }
              subject[:command].should eq "foo bar.com"
            end
          end

          context 'when the user answers "no" to the custom start command' do
            before { stub_ask("Use custom startup command?", :default => false) { false } }

            it 'should not ask for the startup command' do
              dont_allow_ask("Startup command")
              subject
            end
          end
        end

        context 'when the framework is "buildpack"' do
          let(:framework) { buildpack }

          include_examples 'an app that can have a custom start command'
        end

        context 'when the framework is "standalone"' do
          let(:framework) { standalone }

          include_examples 'an app that can have a custom start command'
        end

        context 'when the framework is neither "buildpack" nor "standalone"' do
          let(:framework) { fake(:framework, :name => "java") }

          it 'does not ask if there is a custom start command' do
            dont_allow_ask("Startup command")
            subject
          end
        end
      end

      it 'should ask for the runtime' do
        inputs.delete(:runtime)
        mock_ask('Runtime', anything) do |_, options|
          expect(options[:choices]).to eq runtimes.sort_by(&:name)
          runtime
        end
        subject
      end

      it 'should ask for the memory' do
        inputs.delete(:memory)

        memory_choices = %w(64M 128M 256M 512M 1G)
        stub(create).memory_choices { memory_choices }

        mock_ask('Memory Limit', anything) do |_, options|
          expect(options[:choices]).to eq memory_choices
          "1G"
        end

        subject
      end
    end
  end

  describe '#determine_framework' do
    subject { create.determine_framework }

    context 'when framework is given' do
      let(:inputs) { { :framework => framework } }

      it 'does not try to get the frameworks' do
        any_instance_of(VMC::Detector) do |detector|
          dont_allow(detector).detect_framework
          dont_allow(detector).all_frameworks
        end

        dont_allow_ask
        dont_allow(client).frameworks

        subject
      end

      it { should eq framework }
    end

    context 'when framework is not given' do
      context 'and a framework is detected' do
        it "lists the detected framework and an 'other' option" do
          any_instance_of(VMC::Detector) do |detector|
            mock(detector).detect_framework { framework }
          end

          mock_ask('Framework', anything) do |_, options|
            expect(options[:choices]).to eq [framework, :other] #frameworks.sort_by(&:name)
            framework
          end

          subject
        end
      end

      context 'and a framework is not detected' do
        it "lists all available frameworks" do
          any_instance_of(VMC::Detector) do |detector|
            stub(detector).detect_framework
          end

          mock_ask('Framework', anything) do |_, options|
            expect(options[:choices]).to eq frameworks.sort_by(&:name)
            framework
          end

          subject
        end
      end
    end
  end

  describe '#detect_runtimes' do
    subject { create.determine_runtime(framework) }

    context 'when runtime is given' do
      let(:inputs) { { :runtime => runtime } }

      it 'does not try to get the runtime' do
        any_instance_of(VMC::Detector) do |detector|
          dont_allow(detector).detect_runtime
          dont_allow(detector).all_runtimes
        end

        dont_allow_ask
        dont_allow(client).runtimes

        subject
      end

      it { should eq runtime }
    end

    context 'when runtime is not given' do
      context 'and the framework is standalone' do
        let(:framework) { standalone }

        it "detects the runtime" do
          any_instance_of(VMC::Detector) do |detector|
            mock(detector).detect_runtimes { runtimes }
          end

          mock_ask('Runtime', anything) do |_, options|
            expect(options[:choices]).to eq(runtimes.sort_by(&:name) + [:other])
            runtime
          end

          subject
        end
      end

      context 'and the framework is not standalone' do
        it "gets the runtimes based on the framework" do
          any_instance_of(VMC::Detector) do |detector|
            mock(detector).runtimes(framework) { runtimes }
          end

          mock_ask('Runtime', anything) do |_, options|
            expect(options[:choices]).to eq(runtimes.sort_by(&:name) + [:other])
            runtime
          end

          subject
        end
      end
    end
  end

  describe '#create_app' do
    before { dont_allow_ask }

    let(:app) { fake(:app, :guid => nil) }

    let(:attributes) do
      { :name => "some-app",
        :total_instances => 2,
        :framework => framework,
        :runtime => runtime,
        :production => false,
        :memory => 1024,
        :buildpack => "git://example.com"
      }
    end

    before { stub(client).app { app } }

    subject { create.create_app(attributes) }

    it 'creates an app based on the resulting inputs' do
      mock(create).filter(:create_app, app) { app }

      mock(app).create!

      subject

      attributes.each do |key, val|
        expect(app.send(key)).to eq val
      end
    end
  end

  describe '#map_url' do
    let(:app) { fake(:app) }
    let(:url_choices) { %W(#{app.name}.foo-cloud.com) }

    before do
      stub(create).url_choices { url_choices }
    end

    subject { create.map_url(app) }

    it "maps a url" do
      mock_ask('URL', anything) do |_, options|
        expect(options[:choices]).to eq(url_choices + %w(none))
        expect(options[:default]).to eq url_choices.first
        url_choices.first
      end

      mock(create).invoke(:map, :app => app, :url => url_choices.first)

      subject
    end

    context "when 'none' is given" do
      it "does not perform any mapping" do
        mock_ask('URL', anything) { "none" }

        dont_allow(create).invoke(:map, anything)

        subject
      end
    end

    context "when mapping fails" do
      before do
        mock_ask('URL', anything) { url_choices.first }

        mock(create).invoke(:map, :app => app, :url => url_choices.first) do
          raise CFoundry::RouteHostTaken.new("foo", 1234)
        end
      end

      it "asks again" do
        stub(create).line

        mock_ask('URL', anything) { url_choices.first }

        stub(create).invoke(:map, :app => app, :url => url_choices.first)

        subject
      end

      it "reports the failure message" do
        mock(create).line "foo"
        mock(create).line

        stub_ask('URL', anything) { url_choices.first }

        stub(create).invoke(:map, :app => app, :url => url_choices.first)

        subject
      end
    end
  end

  describe '#create_services' do
    let(:app) { fake(:app) }
    subject { create.create_services(app) }

    context 'when forcing' do
      let(:inputs) { {:force => true} }

      it "does not ask to create any services" do
        dont_allow_ask("Create services for application?", anything)
        subject
      end

      it "does not create any services" do
        dont_allow(create).invoke(:create_service, anything)
        subject
      end
    end

    context 'when not forcing' do
      let(:inputs) { { :force => false } }

      it 'does not create the service if asked not to' do
        mock_ask("Create services for application?", anything) { false }
        dont_allow(create).invoke(:create_service, anything)

        subject
      end

      it 'asks again to create a service' do
        mock_ask("Create services for application?", anything) { true }
        mock(create).invoke(:create_service, { :app => app }, :plan => :interact).ordered

        mock_ask("Create another service?", :default => false) { true }
        mock(create).invoke(:create_service, { :app => app }, :plan => :interact).ordered

        mock_ask("Create another service?", :default => false) { true }
        mock(create).invoke(:create_service, { :app => app }, :plan => :interact).ordered

        mock_ask("Create another service?", :default => false) { false }
        dont_allow(create).invoke(:create_service, anything).ordered

        subject
      end
    end
  end

  describe '#bind_services' do
    let(:app) { fake(:app) }

    subject { create.bind_services(app) }

    context 'when forcing' do
      let(:global) { { :force => true, :color => false, :quiet => true } }

      it "does not ask to bind any services" do
        dont_allow_ask("Bind other services to application?", anything)
        subject
      end

      it "does not bind any services" do
        dont_allow(create).invoke(:bind_service, anything)
        subject
      end
    end

    context 'when not forcing' do
      it 'does not bind the service if asked not to' do
        mock_ask("Bind other services to application?", anything) { false }
        dont_allow(create).invoke(:bind_service, anything)

        subject
      end

      it 'asks again to bind a service' do
        bind_times = 3
        call_count = 0

        mock_ask("Bind other services to application?", anything) { true }

        mock(create).invoke(:bind_service, :app => app).times(bind_times) do
          call_count += 1
          stub(app).services { service_instances.first(call_count) }
        end

        mock_ask("Bind another service?", anything).times(bind_times) do
          call_count < bind_times
        end

        subject
      end

      it 'stops asking if there are no more services to bind' do
        bind_times = service_instances.size
        call_count = 0

        mock_ask("Bind other services to application?", anything) { true }

        mock(create).invoke(:bind_service, :app => app).times(bind_times) do
          call_count += 1
          stub(app).services { service_instances.first(call_count) }
        end

        mock_ask("Bind another service?", anything).times(bind_times - 1) { true }

        subject
      end

      context 'when there are no services' do
        let(:service_instances) { [] }

        it 'does not ask to bind anything' do
          dont_allow_ask
          subject
        end
      end
    end
  end

  describe '#start_app' do
    let(:app) { fake(:app) }
    subject { create.start_app(app) }

    context 'when the start flag is provided' do
      let(:inputs) { {:start => true} }

      it 'invokes the start command' do
        mock(create).invoke(:start, :app => app)
        subject
      end
    end

    context 'when the start flag is not provided' do
      let(:inputs) { {:start => false} }

      it 'invokes the start command' do
        dont_allow(create).invoke(:start, anything)
        subject
      end
    end
  end
end
