require 'spec_helper'

describe VMC::Route::Unmap do
  let(:global) { { :color => false } }
  let(:given) { {} }
  let(:inputs) { {} }
  let(:client) { fake_client }
  let!(:cli) { described_class.new }
  let(:app){ fake(:app, :space => space, :name => "app-name") }
  let(:space) { fake(:space, :name => "space-name", :domains => space_domains) }
  let(:domain) { fake(:domain, :name => domain_name ) }
  let(:domain_name) { "some-domain.com" }
  let(:host_name) { "some-host" }
  let(:url) { "#{host_name}.#{domain_name}" }
  let(:space_domains) { [domain] }

  before do
    stub(cli).client { client }
    stub_output(cli)
  end

  subject { invoke_cli(cli, :unmap, inputs, given, global) }

  describe 'metadata' do
    let(:command) { Mothership.commands[:delete_service] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Delete a service" }
      it { expect(Mothership::Help.group(:services, :manage)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{:type => :optional, :value => nil, :name => :service }])
      end
    end
  end

  context 'when targeting v2' do
    context "when an app and a url are specified" do
      let(:given) { { :url => url } }
      let(:inputs) { { :app => app } }

      context "when the given route is mapped to the given app" do
        let(:client) { fake_client :routes => [route] }
        let(:app) { fake(:app, :space => space, :name => "app-name", :routes => [route]) }
        let(:route) { fake(:route, :space => space, :host => host_name, :domain => domain) }

        it "unmaps the url from the app" do
          mock(app).remove_route(route)
          subject
        end
      end

      context "when the given route is NOT mapped to the given app" do
        it "displays an error" do
          expect { subject }.to raise_error(VMC::UserError, /Unknown route/)
        end
      end
    end

    context "when only an app is specified" do
      let(:other_route) { fake(:route, :host => "abcd", :domain => domain) }
      let(:route) { fake(:route, :host => "efgh", :domain => domain) }
      let(:app) { fake(:app, :space => space, :routes => [route, other_route] )}
      let(:inputs) { { :app => app } }

      before { stub(app).remove_route(route) }

      it "asks the user to select from the app's urls" do
        mock_ask("Which URL?", anything) do |_, opts|
          expect(opts[:choices]).to eq [other_route, route]
          route
        end

        subject
      end

      it "unmaps the selected url from the app" do
        stub_ask("Which URL?", anything) { route }
        mock(app).remove_route(route)
        subject
      end
    end

    context "when an app is specified and the --all option is given" do
      let(:other_route) { fake(:route, :host => "abcd", :domain => domain) }
      let(:route) { fake(:route, :host => "efgh", :domain => domain) }
      let(:app) { fake(:app, :routes => [route, other_route]) }
      let(:inputs) { { :app => app, :all => true } }

      it "unmaps all routes from the given app" do
        mock(app).remove_route(route)
        mock(app).remove_route(other_route)
        subject
      end
    end

    context "when a url is specified and the --delete option is given" do
      let(:route) { fake(:route, :host => host_name, :domain => domain) }
      let(:client) { fake_client :routes => [route] }
      let(:given) { { :url => url } }
      let(:inputs) { { :delete => true } }

      it "deletes the route" do
        mock(route).delete!
        subject
      end
    end

    context "when the --delete and --all options are both passed" do
      let(:inputs) { { :delete => true, :all => true } }
      let(:other_route) { fake(:route, :host => "abcd", :domain => domain) }
      let(:route) { fake(:route, :host => "efgh", :domain => domain) }
      let(:client) { fake_client :routes => [route, other_route] }

      it "asks if the user really wants to unmap all urls" do
        mock_ask("Really delete ALL URLS?", :default => false) { false }
        subject
      end

      context "when the user responds with a yes" do
        before { stub_ask("Really delete ALL URLS?", anything) { true } }

        it "deletes all the user's routes" do
          client.routes.each { |r| mock(r).delete! }
          subject
        end
      end

      context "when the user responds with a no" do
        before { stub_ask("Really delete ALL URLS?", anything) { false } }

        it "does not delete any routes" do
          any_instance_of(route.class) do |route|
            dont_allow(route).delete!
          end
          subject
        end
      end
    end

    context "when only a url is passed" do
      let(:route) { fake(:route, :host => host_name, :domain => domain) }
      let(:client) { fake_client :routes => [route] }
      let(:given) { { :url => url } }

      it "displays an error message" do
        expect { subject }.to raise_error(VMC::UserError, /Missing either --delete or --app/)
      end
    end
  end

  context 'when targeting v1' do
    let(:client) { CFoundry::V1::Client.new }
    let(:app) { CFoundry::V1::App.new("some-app", client) }
    let(:other_url) { "some.other.url.com" }

    context "when an app and a url are specified" do
      let(:given) { { :url => url } }
      let(:inputs) { { :app => app } }

      context "when the given url is not mapped to the app" do
        before { app.urls = [other_url] }

        it "displays an error message" do
          expect { subject }.to raise_error(VMC::UserError, /URL.*not mapped/)
        end
      end

      context "when the given url is mapped to the app" do
        before { app.urls = [url, other_url] }

        it "unmaps the url from the app" do
          mock(app).update!
          subject
          expect(app.urls).to eq [other_url]
        end
      end
    end

    context "when only an app is specified" do
      let(:inputs) { { :app => app } }
      before { app.urls = [url, other_url] }

      it "asks for the url" do
        mock_ask("Which URL?", :choices => [url, other_url]) { url }
        stub(app).update!
        subject
      end

      it "unmaps the selected url from the app" do
        stub_ask("Which URL?", anything) { url }
        mock(app).update!
        subject
        expect(app.urls).to eq [other_url]
      end
    end

    context "when an app is specified and the --all option is given" do
      let(:inputs) { { :app => app, :all => true } }

      it "unmaps all routes from the given app" do
        app.urls = ["foo", "bar"]
        mock(app).update!
        subject
        expect(app.urls).to eq []
      end
    end
  end
end