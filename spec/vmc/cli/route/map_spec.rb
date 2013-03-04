require 'spec_helper'

command VMC::Route::Map do
  let(:client) { fake_client(:apps => apps, :routes => routes) }

  let(:app) { fake(:app, :space => space, :name => "app-name") }
  let(:space) { fake(:space, :domains => space_domains) }
  let(:domain) { fake(:domain) }

  let(:apps) { [app] }
  let(:routes) { [] }
  let(:domains) { [domain] }

  let(:space_domains) { domains }

  let(:host_name) { "some-host" }

  context 'when targeting v2' do
    shared_examples "mapping the route to the app" do
      context 'and the domain is mapped to the space' do
        let(:space_domains) { [domain] }

        context 'and the route is mapped to the space' do
          let(:routes) { [route] }
          let(:route) do
            fake(:route, :space => space, :host => host_name,
                 :domain => domain)
          end

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
            subject
            expect(output).to say("Creating route #{host_name}.#{domain.name}")
          end

          it "creates the route in the app's space" do
            mock(new_route).create!
            subject
            expect(new_route.host).to eq host_name
            expect(new_route.domain).to eq domain
            expect(new_route.space).to eq space
          end

          it 'indicates that it is binding the route' do
            subject
            expect(output).to say("Binding #{host_name}.#{domain.name} to #{app.name}")
          end

          it 'binds the route to the app' do
            mock(app).add_route(new_route)
            subject
          end
        end
      end
    end

    context 'when an app is specified' do
      subject { vmc %W[map #{app.name} #{host_name} #{domain.name}] }

      context 'and the domain is not already mapped to the space' do
        let(:space_domains) { [] }

        it 'indicates that the domain is invalid' do
          subject
          expect(error_output).to say("Unknown domain")
        end
      end

      include_examples "mapping the route to the app"
    end

    context 'when an app is not specified' do
      let(:space_domains) { [domain] }
      let(:new_route) { fake(:route) }

      subject { vmc %W[map --host #{host_name} #{domain.name}] }

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
      let(:new_route) { fake(:route) }

      subject { vmc %W[map #{app.name} #{domain.name}] }

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
    let(:client) { v1_fake_client }
    let(:app) { v1_fake :app, :name => "foo" }

    subject { vmc %W[map #{app.name} foo.bar.com] }

    before do
      stub(client).app_by_name("foo") { app }
    end

    it "adds the domain to the app's urls" do
      stub(app).update!
      subject
      expect(app.urls).to include "foo.bar.com"
    end
  end
end
