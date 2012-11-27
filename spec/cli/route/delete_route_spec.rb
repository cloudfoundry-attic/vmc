require 'spec_helper'
require "vmc/cli/route/delete_route"

describe VMC::Route::DeleteRoute do
  let(:base_inputs) { { :color => false, :quiet => true } }
  let(:inputs) { base_inputs }
  let(:quiet) { true }
  let(:client) { FactoryGirl.build(:client) }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  subject { Mothership.new.invoke(:delete_route, inputs) }

  describe 'helps' do
    subject { Mothership.send(:class_variable_get, :@@commands)[:delete_route] }
    its(:description) { should eq "Delete a route" }
    it { expect(subject.inputs[:route][:description]).to eq "Route to delete" }
    it { expect(subject.inputs[:really][:hidden]).to be_true }
    it { expect(subject.inputs[:all][:description]).to eq "Delete all routes" }
  end

  context 'when there are no routes' do
    let(:routes) { [] }

    context 'and a name is given' do
      let(:inputs) { base_inputs }
      it { expect { subject }.to raise_error(VMC::UserError, "No routes.") }
    end

    context 'and a name is not given' do
      let(:inputs) { base_inputs.merge(:name => "some-route") }
      it { expect { subject }.to raise_error(VMC::UserError, "No routes.") }
    end
  end

  context "when there are routes" do
    let(:client) { FactoryGirl.build(:client, :routes => routes) }
    let(:routes) { FactoryGirl.build_list(:route, 2) }
    let(:deleted_route) { routes.first }

    context 'when the defaults are used' do
      it 'asks for the route and confirmation' do
        mock_ask("Really delete #{deleted_route.name}?", :default => false) { true }
        mock_ask('Which route?', anything) { deleted_route }
        stub(deleted_route).delete!
        subject
      end

      it 'does not try to delete all routes' do
        stub_ask { true }
        stub_ask("Which route?") { deleted_route }
        mock(deleted_route).delete!
        dont_allow(routes.last).delete!
        subject
      end
    end

    context 'when the route is inputted' do
      let(:inputs) { base_inputs.merge(:route => deleted_route) }

      it 'does not ask which route but still asks for confirmation' do
        mock_ask("Really delete #{deleted_route.name}?", :default => false) { true }
        dont_allow_ask('Which route?', anything) { deleted_route }
        stub(deleted_route).delete!
        subject
      end

      it 'deletes the route' do
        stub_ask { true }
        stub_ask("Which route?") { deleted_route }
        mock(deleted_route).delete!
        subject
      end
    end

    context 'when the all flag is provided' do
      let(:inputs) { base_inputs.merge(:all => true) }

      it 'deletes the route' do
        stub_ask { true }
        routes.each do |route|
          mock(route).delete!
        end
        subject
      end

      it 'asks to delete the routes' do
        mock_ask("Really delete ALL ROUTES?", :default => false) { true }
        dont_allow_ask('Which route?', anything) { deleted_route }
        routes.each do |route|
          stub(route).delete!
        end
        subject
      end

      context 'and also with the really flag' do
        let(:inputs) { base_inputs.merge(:all => true, :really => true) }

        it 'does not ask' do
          dont_allow_ask("Really delete ALL ROUTES?", :default => false) { true }
          routes.each do |route|
            stub(route).delete!
          end
          subject
        end
      end
    end

    context 'when the really flag is provided' do
      context 'when no route given' do
        let(:inputs) { base_inputs.merge(:really => true) }

        it 'asks for the route, and does not confirm deletion' do
          dont_allow_ask("Really delete ALL ROUTES?", :default => false) { true }
          mock_ask('Which route?', anything) { deleted_route }
          mock(deleted_route).delete!
          subject
        end
      end

      context 'when a route is given' do
        let(:inputs) { base_inputs.merge(:route => deleted_route, :really => true) }

        it 'asks for the route, and does not confirm deletion' do
          dont_allow_ask("Really delete ALL ROUTES?", :default => false) { true }
          dont_allow_ask('Which route?', anything) { deleted_route }
          mock(deleted_route).delete!
          subject
        end
      end
    end
  end
end
