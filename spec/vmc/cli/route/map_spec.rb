require 'spec_helper'

describe VMC::Route::Map do
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
  let(:url) { "#{host_name}.#{domain_name}" }
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
      let(:inputs) { { :url => url, :app => app } }

      context 'and the domain is not already mapped to the space' do
        it 'indicates that the domain is invalid' do
          expect { subject }.to raise_error(VMC::UserError, /Invalid domain/)
        end
      end

      include_examples "mapping the route to the app"
    end

    context 'when a space is specified' do
      let(:inputs) { { :url => url, :space => space } }

      context 'and the domain is not mapped to the space' do
        it 'indicates that the domain is invalid' do
          expect { subject }.to raise_error(VMC::UserError, /Invalid domain/)
        end
      end

      context 'and the domain is mapped to the space' do
        let(:domain) { fake(:domain, :client => client, :name => domain_name ) }
        let(:new_route) { fake(:route, :host => "new-route-host") }

        before do
          stub(client).route { new_route }
          stub(new_route).create!
          stub(space).domain_by_name(domain_name, anything) { domain }
        end

        context 'and the route does not exist' do
          it 'indicates that it is creating a route' do
            mock(cli).print("Creating route #{host_name}.#{domain_name}")
            subject
          end

          it 'creates the route in the given space' do
            mock(new_route).create!
            subject
            expect(new_route.host).to eq host_name
            expect(new_route.domain).to eq domain
            expect(new_route.space).to eq space
          end
        end
      end
    end

    context 'when neither an app nor a space is specified' do
      let(:inputs) { { :url => url } }
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
  end

  context 'when targeting v1'
end
