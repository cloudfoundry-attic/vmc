require 'spec_helper'
require "vmc/cli/route/delete"

describe VMC::Route::Delete do
  let(:global) { { :color => false, :quiet => true } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:client) { fake_client }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  subject { Mothership.new.invoke(:delete_route, inputs, given, global) }

  describe 'metadata' do
    let(:command) { Mothership.commands[:delete_route] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Delete a route" }
      it { expect(Mothership::Help.group(:routes)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'inputs' do
      subject { command.inputs }
      it { expect(subject[:route][:description]).to eq "Route to delete" }
      it { expect(subject[:really][:hidden]).to be_true }
      it { expect(subject[:all][:description]).to eq "Delete all routes" }
    end

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([
          { :type => :optional, :value => nil, :name => :route }
        ])
      end
    end
  end

  context 'when there are no routes' do
    context 'and a name is given' do
      let(:given) { { :route => "some-route" } }
      it { expect { subject }.to raise_error(VMC::UserError, "Unknown route 'some-route'.") }
    end

    context 'and a name is not given' do
      it { expect { subject }.to raise_error(VMC::UserError, "No routes.") }
    end
  end

  context "when there are routes" do
    let(:client) { fake_client(:routes => routes) }
    let(:routes) { fake_list(:route, 2) }
    let(:deleted_route) { routes.first }

    context 'when the defaults are used' do
      it 'asks for the route and confirmation' do
        mock_ask('Which route?', anything) { deleted_route }
        mock_ask("Really delete #{deleted_route.name}?", :default => false) { true }
        stub(deleted_route).delete!
        subject
      end

      it 'does not try to delete all routes' do
        stub_ask("Which route?", anything) { deleted_route }
        stub_ask(/Really delete/, anything) { true }
        mock(deleted_route).delete!
        dont_allow(routes.last).delete!
        subject
      end
    end

    context 'when the route is inputted' do
      let(:inputs) { { :route => deleted_route } }

      it 'does not ask which route but still asks for confirmation' do
        dont_allow_ask('Which route?', anything)
        mock_ask("Really delete #{deleted_route.name}?", :default => false) { true }
        stub(deleted_route).delete!
        subject
      end

      it 'deletes the route' do
        dont_allow_ask("Which route?", anything)
        stub_ask(/Really delete/, anything) { true }
        mock(deleted_route).delete!
        subject
      end
    end

    context 'when the all flag is provided' do
      let(:inputs) { { :all => true } }

      it 'deletes the route' do
        stub_ask { true }
        routes.each do |route|
          mock(route).delete!
        end
        subject
      end

      it 'asks to delete the routes' do
        mock_ask("Really delete ALL ROUTES?", :default => false) { true }
        dont_allow_ask('Which route?', anything)
        routes.each do |route|
          stub(route).delete!
        end
        subject
      end

      context 'and also with the really flag' do
        let(:inputs) { { :all => true, :really => true } }

        it 'does not ask' do
          dont_allow_ask("Really delete ALL ROUTES?", :default => false)
          routes.each do |route|
            stub(route).delete!
          end
          subject
        end
      end
    end

    context 'when the really flag is provided' do
      context 'when no route given' do
        let(:inputs) { { :really => true } }

        it 'asks for the route, and does not confirm deletion' do
          dont_allow_ask("Really delete ALL ROUTES?", :default => false)
          mock_ask('Which route?', anything) { deleted_route }
          mock(deleted_route).delete!
          subject
        end
      end

      context 'when a route is given' do
        let(:inputs) { { :route => deleted_route, :really => true } }

        it 'asks for the route, and does not confirm deletion' do
          dont_allow_ask("Really delete ALL ROUTES?", :default => false)
          dont_allow_ask('Which route?', anything)
          mock(deleted_route).delete!
          subject
        end

        it 'displays the progress' do
          mock_with_progress("Deleting route #{deleted_route.name}")
          mock(deleted_route).delete!

          subject
        end
      end
    end
  end
end
