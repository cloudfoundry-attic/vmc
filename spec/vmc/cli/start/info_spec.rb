require 'spec_helper'

describe VMC::Start::Info do
  let(:global) { { :color => false } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:output) { StringIO.new }

  let(:client) {
    fake_client :frameworks => fake_list(:framework, 3),
      :runtimes => fake_list(:runtime, 3),
      :services => fake_list(:service, 3)
  }

  let(:target_info) {
    { :description => "Some description",
      :version => 2,
      :support => "http://example.com"
    }
  }

  before do
    any_instance_of(VMC::CLI) do |cli|
      stub(cli).client { client }
    end
  end

  subject do
    with_output_to output do
      Mothership.new.invoke(:info, inputs, given, global)
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:info] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Display information on the current target, user, etc." }
      it { expect(Mothership::Help.group(:start)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'flags' do
      subject { command.flags }

      its(["-f"]) { should eq :frameworks }
      its(["-r"]) { should eq :runtimes }
      its(["-s"]) { should eq :services }
      its(["-a"]) { should eq :all }
    end

    describe 'arguments' do
      subject { command.arguments }
      it { should be_empty }
    end
  end

  context 'when given no flags' do
    it "displays target information" do
      mock(client).info { target_info }

      subject

      output.rewind
      expect(output.readline).to eq "Some description\n"
      expect(output.readline).to eq "\n"
      expect(output.readline).to eq "target: #{client.target}\n"
      expect(output.readline).to eq "  version: 2\n"
      expect(output.readline).to eq "  support: http://example.com\n"
    end
  end

  context 'when given --frameworks' do
    let(:inputs) { { :frameworks => true } }

    it 'does not grab /info' do
      dont_allow(client).info
      subject
    end

    it 'lists frameworks on the target' do
      subject

      output.rewind
      expect(output.readline).to match /Getting frameworks.*OK/
      expect(output.readline).to eq "\n"
      expect(output.readline).to match /framework\s+description/

      client.frameworks.sort_by(&:name).each do |f|
        expect(output.readline).to match /#{f.name}\s+#{f.description}/
      end
    end
  end

  context 'when given --runtimes' do
    let(:inputs) { { :runtimes => true } }

    it 'does not grab /info' do
      dont_allow(client).info
      subject
    end

    it 'lists runtimes on the target' do
      subject

      output.rewind
      expect(output.readline).to match /Getting runtimes.*OK/
      expect(output.readline).to eq "\n"
      expect(output.readline).to match /runtime\s+description/

      client.runtimes.sort_by(&:name).each do |r|
        expect(output.readline).to match /#{r.name}\s+#{r.description}/
      end
    end
  end

  context 'when given --services' do
    let(:inputs) { { :services => true } }

    it 'does not grab /info' do
      dont_allow(client).info
      subject
    end

    it 'lists services on the target' do
      subject

      output.rewind
      expect(output.readline).to match /Getting services.*OK/
      expect(output.readline).to eq "\n"
      expect(output.readline).to match /service\s+version\s+provider\s+plans\s+description/

      client.services.sort_by(&:label).each do |s|
        expect(output.readline).to match /#{s.label}\s+#{s.version}\s+#{s.provider}.+#{s.description}/
      end
    end
  end

  context 'when given --all' do
    let(:inputs) { { :all => true } }

    it 'combines --frameworks --runtimes and --services' do
      mock(client).info { target_info }

      subject

      output.rewind
      expect(output.readline).to match /Getting runtimes.*OK/
      expect(output.readline).to match /Getting frameworks.*OK/
      expect(output.readline).to match /Getting services.*OK/
    end
  end
end
