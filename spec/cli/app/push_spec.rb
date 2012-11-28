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
    xit 'should detect the correct framework'
  end

  describe '#sync_app' do

  end
end