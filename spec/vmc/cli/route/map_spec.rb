require 'spec_helper'

describe VMC::Route::Map do
  let(:inputs) { {} }
  let(:global) { { :color => false } }
  let(:given) { {} }
  let(:client) { fake_client }
  let!(:cli) { described_class.new }

  before do
    stub(cli).client { client }
    stub_output(cli)
  end

  let(:app){ fake(:app, :space => space, :name => "app-name") }
  let(:space) { fake(:space, :name => "space-name", :domains => space_domains) }
  let(:domain) { fake(:domain, :name => domain_name ) }
  let(:domain_name) { "some-domain.com" }
  let(:host_name) { "some-host" }
  let(:space_domains) { [] }

  subject { invoke_cli(cli, :map, inputs, given, global) }

  context 'when targeting v2' do
    shared_examples "mapping the route to the app" do
      context 'and the domain is mapped to the space' do
        let(:space_domains) { [domain] }

        context 'and the route is mapped to the space' do
          let(:client) { fake_client :routes => [route] }
          let(:route) { fake(:route, :space => space, :host => host_name, :domain => domain) }

          it 'binds the route to the app' do
            mock(app).add_route(route)
            subject
          end
        end

        context 'and the route is not mapped to the space' do
          let(:new_route) { fake(:route) }

          before do
            stub(client).route { new_route }
            stub(app).add_route
            stub(new_route).create!
          end

          it 'indicates that it is creating a route' do
            mock(cli).print("Creating route #{host_name}.#{domain_name}")
            subject
          end

          it "creates the route in the app's space" do
            mock(new_route).create!
            subject
            expect(new_route.host).to eq host_name
            expect(new_route.domain).to eq domain
            expect(new_route.space).to eq space
          end

          it 'indicates that it is binding the route' do
            mock(cli).print("Binding #{host_name}.#{domain_name} to app-name")
            subject
          end

          it 'binds the route to the app' do
            mock(app).add_route(new_route)
            subject
          end
        end
      end
    end

    context 'when an app is specified' do
      let(:inputs) { { :domain => domain, :host => host_name, :app => app } }

      context 'and the domain is not already mapped to the space' do
        let(:space_domains) { [] }
        let(:inputs) { { :app => app } }
        let(:given) { { :domain => "some-bad-domain" }}

        it 'indicates that the domain is invalid' do
          expect { subject }.to raise_error(VMC::UserError, /Unknown domain/)
        end
      end

      include_examples "mapping the route to the app"
    end

    context 'when an app is not specified' do
      let(:inputs) { { :domain => domain, :host => host_name } }
      let(:space_domains) { [domain] }
      let(:new_route) { fake(:route) }

      before { stub_ask("Which application?", anything) { app } }

      it 'asks for an app' do
        stub(client).route { new_route }
        stub(app).add_route
        stub(new_route).create!
        mock_ask("Which application?", anything) { app }
        subject
      end

      include_examples "mapping the route to the app"
    end

    context "when a host is not specified" do
      let(:inputs) { { :domain => domain, :app => app } }
      let(:new_route) { fake(:route) }

      before do
        stub(client).route { new_route }
        stub(app).add_route
        stub(new_route).create!
      end

      it "creates a route with an empty string as its host" do
        mock(new_route).create!
        subject
        expect(new_route.host).to eq ""
      end
    end
  end

  context 'when targeting v1' do
    let(:given) { { :domain => "foo.bar.com" } }
    let(:app) { v1_fake :app, :name => "foo" }
    let(:client) { v1_fake_client }
    let(:inputs) { { :app => app } }

    it "adds the domain to the app's urls" do
      stub(app).update!
      subject
      expect(app.urls).to include "foo.bar.com"
    end
  end
end
