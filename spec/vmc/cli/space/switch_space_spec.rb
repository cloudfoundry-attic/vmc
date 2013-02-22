require 'spec_helper'
require "vmc/cli/space/switch"

describe VMC::Space::Switch do
  let(:space_to_switch_to) { spaces.last }
  let(:spaces) { fake_list(:space, 3) }
  let(:organization) { fake(:organization, :spaces => spaces) }
  let(:client) { fake_client(:current_organization => organization, :spaces => spaces) }

  before do
    any_instance_of described_class do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  before do
    described_class.class_eval do
      def wrap_errors
        yield
      end
    end
  end

  after do
    described_class.class_eval do
      remove_method :wrap_errors
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:switch_space] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Switch to a space" }
      it { expect(Mothership::Help.group(:spaces)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{ :type => :normal, :value => nil, :name => :name }])
      end
    end
  end

  subject { vmc %W[--no-quiet switch-space #{space_to_switch_to.name} --no-color] }

  context "when the space exists" do
    it "switches to that space" do
      any_instance_of(Mothership) do |m|
        mock(m).invoke(:target, {:space => space_to_switch_to})
      end

      subject
    end
  end

  context "when the space does not exist" do
    let(:space_to_switch_to) { fake(:space) }

    it "throws a UserError" do
      expect { subject }.to raise_error(VMC::UserError, "The space #{space_to_switch_to.name} does not exist, please create the space first.")
    end
  end
end
