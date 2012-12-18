require 'spec_helper'
require 'stringio'

describe VMC::Organization::Orgs do
  let(:global) { { :color => false } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:output) { StringIO.new }
  let!(:org_1) { FactoryGirl.build(:organization, :name => "bb_second", :spaces => FactoryGirl.build_list(:space, 2), :domains => [FactoryGirl.build(:domain)]) }
  let!(:org_2) { FactoryGirl.build(:organization, :name => "aa_first", :spaces => [FactoryGirl.build(:space)], :domains => FactoryGirl.build_list(:domain, 3)) }
  let!(:org_3) { FactoryGirl.build(:organization, :name => "cc_last", :spaces => FactoryGirl.build_list(:space, 2), :domains => FactoryGirl.build_list(:domain, 2)) }
  let(:organizations) { [org_1, org_2, org_3]}
  let(:client) { FactoryGirl.build(:client, :organizations => organizations) }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  subject do
    with_output_to output do
      Mothership.new.invoke(:orgs, inputs, given, global)
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:orgs] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "List available organizations" }
      it { expect(Mothership::Help.group(:organizations)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has no arguments' do
        should be_empty
      end
    end
  end

  it 'should have the correct first two lines' do
    subject

    output.rewind
    expect(output.readline).to match /Getting organizations.*OK/
    expect(output.readline).to eq "\n"
  end

  context 'when there are no orgnaizations' do
    let(:organizations) { [] }

    context 'and the full flag is given' do
      let(:inputs) { {:full => true} }

      it 'displays yaml-style output with all organization details' do
        any_instance_of VMC::Organization::Orgs do |orgs|
          dont_allow(orgs).invoke
        end
        subject
      end
    end

    context 'and the full flag is not given (default is false)' do
      it 'should show only the progress' do
        subject

        output.rewind
        expect(output.readline).to match /Getting organizations.*OK/
        expect(output).to be_eof
      end
    end
  end

  context 'when there are organizations' do
    context 'and the full flag is given' do
      let(:inputs) { {:full => true} }

      it 'displays yaml-style output with all organization details' do
        any_instance_of VMC::Organization::Orgs do |orgs|
          mock(orgs).invoke(:org, :organization => org_2, :full => true).ordered
          mock(orgs).invoke(:org, :organization => org_1, :full => true).ordered
          mock(orgs).invoke(:org, :organization => org_3, :full => true).ordered
        end
        subject
      end
    end

    context 'and the full flag is not given (default is false)' do
      it 'displays tabular output with names, spaces and domains' do
        subject

        output.rewind
        output.readline
        output.readline

        expect(output.readline).to match /name\s+spaces\s+domains/
        organizations.sort_by(&:name).each do |org|
          expect(output.readline).to match /#{org.name}\s+#{name_list(org.spaces)}\s+#{name_list(org.domains)}/
        end
        expect(output).to be_eof
      end
    end
  end
end
