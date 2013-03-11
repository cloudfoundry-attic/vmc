require 'spec_helper'
require 'fakefs/safe'

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

  let(:path) { "some-path" }

  subject(:create) do
    command = Mothership.commands[:push]
    create = VMC::App::Push.new(command)
    create.path = path
    create.input = Mothership::Inputs.new(command, create, inputs, given, global)
    create.extend VMC::App::PushInteractions
    create
  end

  describe '#get_inputs' do
    subject { create.get_inputs }

    let(:inputs) do
      { :name => "some-name",
        :instances => 1,
        :plan => "p100",
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
      its([:framework]) { should eq nil }
      its([:runtime]) { should eq nil }
      its([:command]) { should eq "ruby main.rb" }
      its([:memory]) { should eq 1024 }
      its([:buildpack]) { should eq "git://example.com" }
    end

    context 'when the command is given' do
      context "and there is a Procfile in the application's root" do
        before do
          FakeFS.activate!
          Dir.mkdir(path)

          # fakefs removes fnmatch :'(
          stub(create.send(:detector)).detect_framework
          File.open("#{path}/Procfile", "w") do |file|
            file.write("this is a procfile")
          end
        end

        after do
          FakeFS.deactivate!
          FakeFS::FileSystem.clear
        end

        its([:command]) { should eq "ruby main.rb" }
      end
    end

    context 'when certain inputs are not given' do
      it 'asks for the name' do
        inputs.delete(:name)
        mock_ask("Name") { "some-name" }
        subject
      end

      it 'asks for the total instances' do
        inputs.delete(:instances)
        mock_ask("Instances", anything) { 1 }
        subject
      end

      it 'does not ask for the framework' do
        dont_allow_ask('Framework', anything) do |_, options|
          expect(options[:choices]).to eq frameworks.sort_by(&:name)
          framework
        end
        subject
      end

      context 'when the command is not given' do
        before { inputs.delete(:command) }

        shared_examples 'an app that can have a custom start command' do
          it "asks for a start command with a default as 'none'" do
            mock_ask("Custom startup command", :default => "none") do
              "abcd"
            end

            expect(subject[:command]).to eq "abcd"
          end

          context "when the user enters 'none'" do
            it "has the command as nil" do
              stub_ask("Custom startup command", :default => "none") do
                "none"
              end

              expect(subject[:command]).to be_nil
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

        describe "getting the start command" do
          before do
            FakeFS.activate!
            Dir.mkdir(path)

            # fakefs removes fnmatch :'(
            stub(create.send(:detector)).detect_framework
          end

          after do
            FakeFS.deactivate!
            FakeFS::FileSystem.clear
          end

          context "when there is a Procfile in the app's root" do
            before do
              File.open("#{path}/Procfile", "w") do |file|
                file.write("this is a procfile")
              end
            end

            it 'does not ask for a start command' do
              dont_allow_ask("Startup command")
              subject
            end
          end

          context "when there is no Procfile in the app's root" do
            it 'asks for a start command' do
              mock_ask("Custom startup command", :default => "none")
              subject
            end
          end
        end
      end

      it 'does not ask for the runtime' do
        dont_allow_ask('Runtime', anything) do |_, options|
          expect(options[:choices]).to eq runtimes.sort_by(&:name)
          runtime
        end
        subject
      end

      it 'asks for the memory' do
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
    let(:space) { fake(:space, :name => "some-space") }

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

    before do
      stub(client).app { app }
      stub(client).current_space { space }
    end

    subject { create.create_app(attributes) }

    it 'creates an app based on the resulting inputs' do
      mock(create).filter(:create_app, app) { app }

      mock(app).create!

      subject

      attributes.each do |key, val|
        expect(app.send(key)).to eq val
      end
    end

    context "when the user does not have permission to create apps" do
      it "fails with a friendly message" do
        stub(app).create! { raise CFoundry::NotAuthorized, "foo" }

        expect { subject }.to raise_error(
          VMC::UserError,
          "You need the Project Developer role in some-space to push.")
      end
    end

    context "with an invalid buildpack" do
      before do
        stub(app).create! do
          raise CFoundry::MessageParseError.new(
            "Request invalid due to parse error: Field: buildpack, Error: Value git@github.com:cloudfoundry/heroku-buildpack-ruby.git doesn't match regexp String /GIT_URL_REGEX/",
            1001)
        end
      end

      it "fails and prints a pretty message" do
        stub(create).line(anything)
        expect { subject }.to raise_error(
          VMC::UserError, "Buildpack must be a public git repository URI.")
      end
    end
  end

  describe '#map_url' do
    let(:app) { fake(:app, :space => space) }
    let(:space) { fake(:space, :domains => domains) }
    let(:domains) { [fake(:domain, :name => "foo.com")] }
    let(:hosts) { [app.name] }

    subject { create.map_route(app) }

    it "asks for a subdomain with 'none' as an option" do
      mock_ask('Subdomain', anything) do |_, options|
        expect(options[:choices]).to eq(hosts + %w(none))
        expect(options[:default]).to eq hosts.first
        hosts.first
      end

      stub_ask("Domain", anything) { domains.first }

      stub(create).invoke

      subject
    end

    it "asks for a domain with 'none' as an option" do
      stub_ask("Subdomain", anything) { hosts.first }

      mock_ask('Domain', anything) do |_, options|
        expect(options[:choices]).to eq(domains + %w(none))
        expect(options[:default]).to eq domains.first
        domains.first
      end

      stub(create).invoke

      subject
    end

    it "maps the host and domain after both are given" do
      stub_ask('Subdomain', anything) { hosts.first }
      stub_ask('Domain', anything) { domains.first }

      mock(create).invoke(:map,
        :app => app, :host => hosts.first,
        :domain => domains.first)

      subject
    end

    context "when 'none' is given as the host" do
      context "and a domain is provided afterwards" do
        it "invokes 'map' with an empty host" do
          mock_ask('Subdomain', anything) { "none" }
          stub_ask('Domain', anything) { domains.first }

          mock(create).invoke(:map,
            :host => "", :domain => domains.first, :app => app)

          subject
        end
      end
    end

    context "when 'none' is given as the domain" do
      it "does not perform any mapping" do
        stub_ask('Subdomain', anything) { "foo" }
        mock_ask('Domain', anything) { "none" }

        dont_allow(create).invoke(:map, anything)

        subject
      end
    end

    context "when mapping fails" do
      before do
        mock_ask('Subdomain', anything) { "foo" }
        mock_ask('Domain', anything) { domains.first }

        mock(create).invoke(:map,
            :host => "foo", :domain => domains.first, :app => app) do
          raise CFoundry::RouteHostTaken.new("foo", 1234)
        end
      end

      it "asks again" do
        stub(create).line

        mock_ask('Subdomain', anything) { hosts.first }
        mock_ask('Domain', anything) { domains.first }

        stub(create).invoke

        subject
      end

      it "reports the failure message" do
        mock(create).line "foo"
        mock(create).line

        stub_ask('Subdomain', anything) { hosts.first }
        stub_ask('Domain', anything) { domains.first }

        stub(create).invoke

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

  describe '#memory_choices' do
    let(:info) { {} }

    before do
      stub(client).info { info }
    end

    context "when the user has usage information" do
      let(:info) do
        { :usage => { :memory => 512 },
          :limits => { :memory => 2048 }
        }
      end

      it "asks for the memory with the ceiling taking the memory usage into account" do
        expect(subject.memory_choices).to eq(%w[64M 128M 256M 512M 1G])
      end
    end

    context "when the user does not have usage information" do
      let(:info) { {:limits => { :memory => 2048 } } }

      it "asks for the memory with the ceiling as their overall limit" do
        expect(subject.memory_choices).to eq(%w[64M 128M 256M 512M 1G 2G])
      end
    end
  end
end
